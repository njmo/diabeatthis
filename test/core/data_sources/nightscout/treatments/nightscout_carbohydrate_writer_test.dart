import 'dart:convert';

import 'package:diabeatthis/core/data_sources/nightscout/treatments/nightscout_carbohydrate_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/treatments/nightscout_upload_needs_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final eatenAt = DateTime.utc(2026, 11, 3, 12);
  const id = '01234567-89ab-4cde-8fab-0123456789ab';

  test(
    'lost POST response recovers the same remote entry without posting twice',
    () async {
      Map<String, dynamic>? stored;
      var posts = 0;
      final writer = NightscoutCarbohydrateWriter(
        client: MockClient((request) async {
          if (request.url.path.contains('/authorization/')) {
            return http.Response('{"token":"jwt"}', 200);
          }
          expect(request.headers['Authorization'], 'Bearer jwt');
          if (request.method == 'GET') {
            return stored == null
                ? http.Response('{}', 404)
                : http.Response(jsonEncode({'result': stored}), 200);
          }
          posts++;
          stored = jsonDecode(request.body) as Map<String, dynamic>;
          expect(stored!['eventType'], 'Carb Correction');
          expect(stored!['identifier'], id);
          expect(stored!['carbs'], 12.5);
          expect(stored!.containsKey('insulin'), isFalse);
          throw http.ClientException('response lost');
        }),
      );
      var marked = 0;
      Future<String> deliver() => writer.deliver(
        source: 'https://example.test/ns?token=old',
        token: 'new',
        identifier: id,
        eatenAt: eatenAt,
        carbs: 12.5,
        allowCreate: true,
        beforeCreate: () async {
          marked++;
        },
      );
      await expectLater(deliver(), throwsA(isA<http.ClientException>()));
      expect(await deliver(), id);
      expect(posts, 1);
      expect(marked, 1);
    },
  );

  test('failed remote verification never falls through to POST', () async {
    var posts = 0;
    final writer = NightscoutCarbohydrateWriter(
      client: MockClient((request) async {
        if (request.url.path.contains('/authorization/')) {
          return http.Response('{"token":"jwt"}', 200);
        }
        if (request.method == 'POST') posts++;
        return http.Response('unavailable', 503);
      }),
    );
    await expectLater(
      writer.deliver(
        source: 'https://example.test',
        token: 'token',
        identifier: id,
        eatenAt: eatenAt,
        carbs: 12,
        allowCreate: true,
        beforeCreate: () async {},
      ),
      throwsStateError,
    );
    expect(posts, 0);
  });

  test(
    'deleted or stale local entries can only verify, never create',
    () async {
      var posts = 0;
      final writer = NightscoutCarbohydrateWriter(
        client: MockClient((request) async {
          if (request.url.path.contains('/authorization/')) {
            return http.Response('{"token":"jwt"}', 200);
          }
          if (request.method == 'POST') posts++;
          return http.Response('{}', 404);
        }),
      );
      await expectLater(
        writer.deliver(
          source: 'https://example.test',
          token: 'token',
          identifier: id,
          eatenAt: eatenAt,
          carbs: 12,
          allowCreate: false,
          beforeCreate: () async {},
        ),
        throwsA(isA<NightscoutUploadNeedsReview>()),
      );
      expect(posts, 0);
    },
  );
}
