import 'dart:convert';

import 'package:http/http.dart' as http;

import '../helpers/nightscout_source_key.dart';
import 'nightscout_upload_needs_review.dart';

/// V3 identifiers make retries idempotent even after a lost POST response.
class NightscoutCarbohydrateWriter {
  NightscoutCarbohydrateWriter({this.client});
  final http.Client? client;

  Future<String> deliver({
    required String source,
    required String token,
    required String identifier,
    required DateTime eatenAt,
    required double carbs,
    required Future<void> Function() beforeCreate,
    required bool allowCreate,
  }) async {
    if (token.trim().isEmpty || !carbs.isFinite || carbs <= 0) {
      throw ArgumentError('Invalid carbohydrate upload');
    }
    final base = nightscoutSourceKey(source);
    final requestClient = client ?? http.Client();
    try {
      final auth = await requestClient
          .get(
            Uri.parse(
              '$base/api/v2/authorization/request/${Uri.encodeComponent(token.trim())}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      _check(auth);
      final jwt = (jsonDecode(auth.body) as Map)['token'];
      if (jwt is! String || jwt.isEmpty) {
        throw StateError('Nightscout authorization unavailable');
      }
      final headers = {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      };
      final existing = await requestClient
          .get(
            Uri.parse('$base/api/v3/treatments/$identifier'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      if (existing.statusCode != 404) {
        _check(existing);
        final result = (jsonDecode(existing.body) as Map)['result'];
        if (result is! Map ||
            result['identifier'] != identifier ||
            result['carbs'] is! num ||
            (result['carbs'] as num).toDouble() != carbs ||
            result['isValid'] == false ||
            result['date'] != eatenAt.millisecondsSinceEpoch) {
          throw const NightscoutUploadNeedsReview();
        }
        return result['_id'] as String? ?? identifier;
      }
      if (!allowCreate) throw const NightscoutUploadNeedsReview();
      await beforeCreate();
      final response = await requestClient
          .post(
            Uri.parse('$base/api/v3/treatments'),
            headers: headers,
            body: jsonEncode({
              'identifier': identifier,
              'eventType': 'Carb Correction',
              'created_at': eatenAt.toUtc().toIso8601String(),
              'date': eatenAt.millisecondsSinceEpoch,
              'carbs': carbs,
              'duration': 0,
              'enteredBy': 'Diabeatthis',
              'app': 'Diabeatthis',
            }),
          )
          .timeout(const Duration(seconds: 20));
      _check(response);
      final result = jsonDecode(response.body) as Map;
      if (result['identifier'] != identifier) {
        throw StateError('Upload acknowledgement missing');
      }
      // Verify the remote receipt before linking it with local history.
      final verified = await requestClient
          .get(
            Uri.parse('$base/api/v3/treatments/$identifier'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));
      _check(verified);
      final receipt = (jsonDecode(verified.body) as Map)['result'];
      if (receipt is! Map ||
          receipt['identifier'] != identifier ||
          receipt['isValid'] == false ||
          receipt['carbs'] != carbs ||
          receipt['date'] != eatenAt.millisecondsSinceEpoch) {
        throw const NightscoutUploadNeedsReview();
      }
      return receipt['_id'] as String? ?? identifier;
    } finally {
      if (client == null) requestClient.close();
    }
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Neither URLs nor response bodies containing credentials leave this adapter.
      throw StateError(
        'Nightscout carbohydrate request failed (${response.statusCode})',
      );
    }
  }
}
