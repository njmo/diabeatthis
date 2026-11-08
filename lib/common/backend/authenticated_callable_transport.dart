import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class CallableIdentity {
  const CallableIdentity(this.uid, this.idToken, this.appCheckToken);
  final String uid;
  final String idToken;
  final String appCheckToken;
}

class CallableFailure implements Exception {
  const CallableFailure(this.code, {this.rejectionCode});
  final String code;

  /// Whitelisted definitive server refusal; absent for ambiguous transport errors.
  final String? rejectionCode;
}

/// Authenticated calls never accept an identity, family or recipient override.
class AuthenticatedCallableTransport {
  const AuthenticatedCallableTransport({
    required this.client,
    required this.projectId,
    required this.identity,
    required this.currentUid,
  });
  final http.Client client;
  final String projectId;
  final Future<CallableIdentity> Function() identity;
  final String? Function() currentUid;
  static const functions = {
    'mealDecision',
    'registerMealDecisionNotifications',
    'claimFamilyPlan',
    'submitFamilyPlan',
    'fetchFamilyPlans',
    'acknowledgeFamilyPlan',
    'registerFamilyMirror',
    'publishFamilyMirror',
    'fetchFamilyMirror',
    'createFamilyInvite',
    'requestFamilyJoin',
    'decideFamilyJoin',
    'getFamilyStatus',
    'disconnectFamilyMember',
    'finalizeFamilySetup',
  };
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, Object?> data, {
    String? expectedUid,
    Future<bool> Function()? allowRequest,
  }) async {
    if (!functions.contains(function)) {
      throw const CallableFailure('invalid-argument');
    }
    final initiatingUid = expectedUid ?? currentUid();
    if (initiatingUid == null) throw const CallableFailure('unauthenticated');
    try {
      final account = await identity().timeout(const Duration(seconds: 15));
      if (account.uid != initiatingUid ||
          account.uid != currentUid() ||
          account.idToken.isEmpty ||
          account.appCheckToken.isEmpty ||
          projectId.isEmpty) {
        throw const CallableFailure('unauthenticated');
      }
      if (allowRequest != null && !await allowRequest()) {
        throw const CallableFailure('cancelled');
      }
      if (currentUid() != initiatingUid) {
        throw const CallableFailure('unauthenticated');
      }
      final response = await client
          .post(
            Uri.https(
              'europe-west1-$projectId.cloudfunctions.net',
              '/$function',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${account.idToken}',
              'X-Firebase-AppCheck': account.appCheckToken,
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(const Duration(seconds: 20));
      if (account.uid != currentUid()) {
        throw const CallableFailure('unauthenticated');
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || body['error'] != null) {
        const rejections = {
          'INVALID_ARGUMENT': 'invalid-argument',
          'UNAUTHENTICATED': 'unauthenticated',
          'PERMISSION_DENIED': 'permission-denied',
          'FAILED_PRECONDITION': 'failed-precondition',
          'ALREADY_EXISTS': 'already-exists',
          'NOT_FOUND': 'not-found',
        };
        final error = body['error'];
        final rejection =
            response.statusCode >= 400 &&
                response.statusCode < 500 &&
                error is Map
            ? rejections[error['status']]
            : null;
        throw CallableFailure('unavailable', rejectionCode: rejection);
      }
      return Map<String, dynamic>.from(body['result'] as Map);
    } on CallableFailure {
      rethrow;
    } catch (_) {
      throw const CallableFailure('unavailable');
    }
  }
}
