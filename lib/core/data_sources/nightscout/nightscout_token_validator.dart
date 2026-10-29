import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../logger/logger.dart';

final nightscoutTokenValidatorProvider = Provider<NightscoutTokenValidator>(
  (_) => NightscoutTokenValidator(),
);

enum NightscoutTokenIssue { required, invalid, treatmentAccess, unavailable }

class NightscoutTokenValidationException implements Exception {
  const NightscoutTokenValidationException(this.issue);

  final NightscoutTokenIssue issue;

  @override
  String toString() => 'Nightscout token validation failed: ${issue.name}';
}

/// Checks identity and permissions with GET requests only. A public status page
/// or a successful anonymous read cannot establish that the supplied token works.
class NightscoutTokenValidator with Logging {
  NightscoutTokenValidator({this.client});

  final http.Client? client;

  Future<void> validate({
    required String url,
    required String token,
    bool requireTreatmentWrite = true,
  }) async {
    final accessToken = token.trim();
    if (accessToken.isEmpty) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.required,
      );
    }
    final requestClient = client ?? http.Client();
    try {
      final base = Uri.parse(url.trim()).replace(userInfo: '');
      if (!['https', 'http'].contains(base.scheme) || base.host.isEmpty) {
        throw const NightscoutTokenValidationException(
          NightscoutTokenIssue.unavailable,
        );
      }
      final prefix = base.pathSegments
          .where((part) => part.isNotEmpty)
          .toList();
      // Drop credentials from the saved URL: only the token being checked may
      // authorize these requests, even when the site URL embeds another token.
      final authorization = base.replace(
        pathSegments: [
          ...prefix,
          'api',
          'v2',
          'authorization',
          'request',
          accessToken,
        ],
        query: '',
        fragment: '',
      );
      final identity = await _get(requestClient, authorization);
      final jwt = identity['token'];
      if (jwt is! String || jwt.trim().isEmpty) {
        throw const NightscoutTokenValidationException(
          NightscoutTokenIssue.invalid,
        );
      }
      final status = await _get(
        requestClient,
        base.replace(
          pathSegments: [...prefix, 'api', 'v3', 'status'],
          query: '',
          fragment: '',
        ),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      final result = status['result'];
      if (result is! Map || result['apiPermissions'] is! Map) {
        throw const NightscoutTokenValidationException(
          NightscoutTokenIssue.unavailable,
        );
      }
      if (requireTreatmentWrite) {
        final permissions = (result['apiPermissions'] as Map)['treatments'];
        logI(
          'Nightscout treatment token access: read=${permissions is String && permissions.contains('r')}, create=${permissions is String && permissions.contains('c')}',
        );
        if (permissions is! String ||
            !permissions.contains('c') ||
            !permissions.contains('r')) {
          // Some deployments summarize split roles as read-only even though
          // authorization grants create separately. Hints never grant access:
          // confirm both permissions through the same v2 guard used by v1 writes.
          if (_hasCreationHint(identity['permissionGroups'])) {
            for (final action in ['read', 'create']) {
              await _checkPermission(
                requestClient,
                base.replace(
                  pathSegments: [
                    ...prefix,
                    'api',
                    'v2',
                    'authorization',
                    'debug',
                    'check',
                    'api:treatments:$action',
                  ],
                  query: '',
                  fragment: '',
                ),
                jwt,
              );
              logI('Nightscout direct treatment permission verified: $action');
            }
            return;
          }
          throw const NightscoutTokenValidationException(
            NightscoutTokenIssue.treatmentAccess,
          );
        }
      }
    } on NightscoutTokenValidationException {
      rethrow;
    } catch (_) {
      // Network exceptions can contain the URL, access token, or JWT.
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.unavailable,
      );
    } finally {
      if (client == null) requestClient.close();
    }
  }

  bool _hasCreationHint(Object? permissionGroups) {
    if (permissionGroups is! List) return false;
    return permissionGroups
        .whereType<List>()
        .expand((group) => group)
        .whereType<String>()
        .any((permission) {
          final actions = permission.split(':').last.split(',');
          return actions.contains('*') || actions.contains('create');
        });
  }

  Future<void> _checkPermission(
    http.Client requestClient,
    Uri uri,
    String jwt,
  ) async {
    final Map<String, dynamic> result;
    try {
      result = await _get(
        requestClient,
        uri,
        headers: {'Authorization': 'Bearer $jwt'},
      );
    } on NightscoutTokenValidationException catch (error) {
      if (error.issue == NightscoutTokenIssue.invalid) {
        throw const NightscoutTokenValidationException(
          NightscoutTokenIssue.treatmentAccess,
        );
      }
      rethrow;
    }
    if (result['check'] == false) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.treatmentAccess,
      );
    }
    if (result['check'] != true) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.unavailable,
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    http.Client requestClient,
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await requestClient
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.invalid,
      );
    }
    if (response.statusCode != 200) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.unavailable,
      );
    }
    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.unavailable,
      );
    }
    if (json['status'] == 401 || json['status'] == 403) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.invalid,
      );
    }
    if (json['status'] is num && json['status'] != 200) {
      throw const NightscoutTokenValidationException(
        NightscoutTokenIssue.unavailable,
      );
    }
    return json;
  }
}
