import 'dart:convert';

import 'package:diabeatthis/core/data_sources/nightscout/temporary_targets/nightscout_temp_target_writer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'posts a new AAPS treatment with consistent UTC timestamps and token',
    () async {
      late http.Request request;
      final writer = NightscoutTempTargetWriter(
        client: MockClient((value) async {
          request = value;
          return http.Response('[{"_id":"new-id"}]', 201);
        }),
      );
      final start = DateTime.parse('2026-10-29T17:30:00+01:00');
      await writer.send(
        url: 'https://example.com/nightscout/?token=old',
        token: 'write-token',
        startsAt: start,
        target: 140,
        durationMinutes: 90,
        reason: 'Activity',
      );
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.method, 'POST');
      expect(request.url.path, '/nightscout/api/v1/treatments.json');
      expect(request.url.queryParameters['token'], 'write-token');
      expect(body, {
        'eventType': 'Temporary Target',
        'created_at': start.toUtc().toIso8601String(),
        'date': start.millisecondsSinceEpoch,
        'duration': 90,
        'targetBottom': 140,
        'targetTop': 140,
        'units': 'mg/dl',
        'reason': 'Activity',
        'enteredBy': 'Diabeatthis',
      });
    },
  );

  test(
    'rejects invalid targets and missing tokens without a request',
    () async {
      var calls = 0;
      final writer = NightscoutTempTargetWriter(
        client: MockClient((_) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      for (final value in [71, 181]) {
        await expectLater(
          writer.send(
            url: 'https://example.com',
            token: 'token',
            startsAt: DateTime.now(),
            target: value,
            durationMinutes: 90,
            reason: 'Activity',
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        writer.send(
          url: 'https://example.com',
          token: '',
          startsAt: DateTime.now(),
          target: 140,
          durationMinutes: 90,
          reason: 'Activity',
        ),
        throwsArgumentError,
      );
      expect(calls, 0);
    },
  );

  test('reports rejected authentication without leaking credentials', () async {
    final writer = NightscoutTempTargetWriter(
      client: MockClient((_) async => http.Response('sensitive-response', 403)),
    );
    await expectLater(
      writer.send(
        url: 'https://example.com',
        token: 'secret-token',
        startsAt: DateTime.now(),
        target: 90,
        durationMinutes: 45,
        reason: 'Eating Soon',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('403'),
            isNot(contains('secret-token')),
            isNot(contains('sensitive-response')),
          ),
        ),
      ),
    );
  });
}
