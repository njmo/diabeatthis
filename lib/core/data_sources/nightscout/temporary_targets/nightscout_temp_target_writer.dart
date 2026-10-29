import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../common/temporary_targets/owned_temp_target.dart';
import '../../../../common/temporary_targets/temp_target_treatment.dart';
import '../../../logger/logger.dart';
import 'nightscout_temp_target_write_exception.dart';

class NightscoutTempTargetWriter with Logging {
  NightscoutTempTargetWriter({this.client});

  final http.Client? client;

  Future<String?> send({
    required String url,
    required String token,
    required DateTime startsAt,
    required int target,
    required int durationMinutes,
    required String reason,
  }) async {
    if (token.trim().isEmpty ||
        target < 72 ||
        target > 180 ||
        durationMinutes <= 0) {
      throw ArgumentError('Invalid temporary target or missing write token');
    }
    return _post(url, token, startsAt, {
      'duration': durationMinutes,
      'targetBottom': target,
      'targetTop': target,
      'units': 'mg/dl',
      'reason': reason,
    });
  }

  Uri _uri(String url, String token, [Map<String, String> query = const {}]) {
    if (token.trim().isEmpty) throw ArgumentError('Missing write token');
    final base = Uri.parse(url.trim());
    if (!['https', 'http'].contains(base.scheme) || base.host.isEmpty) {
      throw ArgumentError('Invalid Nightscout URL');
    }
    return base.replace(
      path:
          '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/v1/treatments.json',
      queryParameters: {
        ...base.queryParameters,
        ...query,
        'token': token.trim(),
      },
      fragment: '',
    );
  }

  Future<List<Map<String, dynamic>>> _read(
    String url,
    String token,
    Map<String, String> query,
  ) async {
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .get(
            _uri(url, token, {
              'find[eventType]': 'Temporary Target',
              'count': '100',
              'sort[created_at]': '-1',
              ...query,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('Could not verify current temporary target');
      }
      final data = jsonDecode(response.body) as List;
      return data
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();
    } finally {
      if (client == null) requestClient.close();
    }
  }

  /// Future-dated records must not hide the treatment effective at [at].
  /// Keep zero-duration and invalid records: these are barriers to older targets.
  Future<Map<String, dynamic>?> latest(
    String url,
    String token, {
    DateTime? at,
  }) async {
    final entries = await _read(url, token, {
      if (at != null) 'find[created_at][\$lte]': at.toUtc().toIso8601String(),
    });
    final eligible =
        entries.where((entry) {
          final start = TempTargetTreatment.startedAt(entry);
          return start != null && (at == null || !start.isAfter(at));
        }).toList()..sort(
          (a, b) => TempTargetTreatment.startedAt(
            b,
          )!.compareTo(TempTargetTreatment.startedAt(a)!),
        );
    return eligible.firstOrNull;
  }

  /// Reconcile a crash or uncertain POST using its exact original start time.
  Future<Map<String, dynamic>?> findCreated(
    OwnedTempTarget attempted,
    String token,
  ) async {
    final entries = await _read(attempted.source, token, {
      'find[created_at][\$gte]': attempted.startedAt
          .subtract(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
      'find[created_at][\$lte]': attempted.startedAt
          .add(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
    });
    final matches = entries.where(attempted.matchesCreated).toList();
    return matches.length == 1 ? matches.single : null;
  }

  Future<bool> containsStop(String url, String token, DateTime at) async {
    final entries = await _read(url, token, {
      'find[created_at][\$gte]': at
          .subtract(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
      'find[created_at][\$lte]': at
          .add(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
    });
    return entries.any(
      (entry) =>
          entry['eventType'] == 'Temporary Target' &&
          entry['enteredBy'] == 'Diabeatthis' &&
          TempTargetTreatment.startedAt(entry)?.millisecondsSinceEpoch ==
              at.millisecondsSinceEpoch &&
          TempTargetTreatment.duration(entry) == Duration.zero,
    );
  }

  Future<void> stop({
    required String url,
    required String token,
    required DateTime at,
  }) async {
    await _post(url, token, at, {'duration': 0});
  }

  Future<String?> _post(
    String url,
    String token,
    DateTime startsAt,
    Map<String, Object> fields,
  ) async {
    final uri = _uri(url, token);
    final start = startsAt.toUtc();
    final requestClient = client ?? http.Client();
    try {
      final response = await requestClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'eventType': 'Temporary Target',
              'created_at': start.toIso8601String(),
              'date': start.millisecondsSinceEpoch,
              ...fields,
              'enteredBy': 'Diabeatthis',
            }),
          )
          .timeout(const Duration(seconds: 20));
      logI(
        'Temporary target POST completed: status=${response.statusCode}, cancellation=${fields['duration'] == 0}',
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // Do not expose response bodies or URLs containing credentials.
        throw NightscoutTempTargetWriteException(response.statusCode);
      }
      if (response.body.trim().isEmpty) return null;
      final decoded = jsonDecode(response.body);
      final entry = decoded is List ? decoded.firstOrNull : decoded;
      return entry is Map ? entry['_id'] as String? : null;
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
