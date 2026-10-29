import 'dart:async';
import 'dart:convert';

import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Matcher issue(NightscoutTokenIssue value) =>
      isA<NightscoutTokenValidationException>().having(
        (error) => error.issue,
        'issue',
        value,
      );

  test('empty and whitespace tokens fail before any request', () async {
    var requests = 0;
    final validator = NightscoutTokenValidator(
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    for (final token in ['', '   ', '\n\t']) {
      await expectLater(
        validator.validate(url: 'https://example.com', token: token),
        throwsA(issue(NightscoutTokenIssue.required)),
      );
    }
    expect(requests, 0);
  });

  test(
    'authenticates the supplied token and checks treatment read/create without writing data',
    () async {
      final requests = <http.Request>[];
      final validator = NightscoutTokenValidator(
        client: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            return http.Response(jsonEncode({'token': 'signed-jwt'}), 200);
          }
          return http.Response(
            jsonEncode({
              'status': 200,
              'result': {
                'apiPermissions': {'treatments': 'cr'},
              },
            }),
            200,
          );
        }),
      );
      await validator.validate(
        url: 'https://example.com/nightscout/?token=old-token#fragment',
        token: ' new-token ',
      );
      expect(requests.map((request) => request.method), ['GET', 'GET']);
      expect(
        requests.first.url.path,
        '/nightscout/api/v2/authorization/request/new-token',
      );
      expect(requests.last.url.path, '/nightscout/api/v3/status');
      expect(
        requests.every(
          (request) =>
              request.url.queryParameters.isEmpty &&
              request.url.fragment.isEmpty,
        ),
        isTrue,
      );
      expect(requests.last.headers['Authorization'], 'Bearer signed-jwt');
      expect(requests.every((request) => request.body.isEmpty), isTrue);
    },
  );

  for (final permissions in ['r', 'c', '', 'ud']) {
    test(
      'permissions "$permissions" cannot enable temporary target uploads',
      () async {
        var requests = 0;
        final validator = NightscoutTokenValidator(
          client: MockClient((_) async {
            requests++;
            return http.Response(
              jsonEncode(
                requests == 1
                    ? {'token': 'jwt'}
                    : {
                        'result': {
                          'apiPermissions': {'treatments': permissions},
                        },
                      },
              ),
              200,
            );
          }),
        );
        await expectLater(
          validator.validate(
            url: 'https://example.com',
            token: 'read-only-token',
          ),
          throwsA(issue(NightscoutTokenIssue.treatmentAccess)),
        );
        expect(requests, 2);
      },
    );
  }

  test(
    'a read-only token may be checked without enabling target uploads',
    () async {
      var requests = 0;
      final validator = NightscoutTokenValidator(
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode(
              requests == 1
                  ? {'token': 'jwt'}
                  : {
                      'result': {
                        'apiPermissions': {'treatments': 'r'},
                      },
                    },
            ),
            200,
          );
        }),
      );
      await validator.validate(
        url: 'https://example.com',
        token: 'read-only-token',
        requireTreatmentWrite: false,
      );
    },
  );

  for (final status in [401, 403]) {
    test(
      'HTTP $status rejects the supplied token despite a public site',
      () async {
        final validator = NightscoutTokenValidator(
          client: MockClient(
            (_) async => http.Response('sensitive-token-response', status),
          ),
        );
        await expectLater(
          validator.validate(
            url: 'https://example.com?token=old-valid-token',
            token: 'invalid-token',
          ),
          throwsA(issue(NightscoutTokenIssue.invalid)),
        );
      },
    );
  }

  test(
    'JWT rejection prevents a successful public status page from masking an invalid token',
    () async {
      var requests = 0;
      final validator = NightscoutTokenValidator(
        client: MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('{"token":"jwt"}', 200)
              : http.Response('{"status":401}', 200);
        }),
      );
      await expectLater(
        validator.validate(url: 'https://example.com', token: 'invalid-token'),
        throwsA(issue(NightscoutTokenIssue.invalid)),
      );
    },
  );

  test(
    'a public response without a JWT is not proof of a valid token',
    () async {
      final validator = NightscoutTokenValidator(
        client: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
      );
      await expectLater(
        validator.validate(url: 'https://example.com', token: 'invalid-token'),
        throwsA(issue(NightscoutTokenIssue.invalid)),
      );
    },
  );

  for (final body in ['{}', '{"result":{}}', '<html>Login</html>', '[]']) {
    test(
      'missing or unreadable permission data cannot enable uploads: $body',
      () async {
        var requests = 0;
        final validator = NightscoutTokenValidator(
          client: MockClient(
            (_) async =>
                http.Response(++requests == 1 ? '{"token":"jwt"}' : body, 200),
          ),
        );
        await expectLater(
          validator.validate(url: 'https://example.com', token: 'token'),
          throwsA(issue(NightscoutTokenIssue.unavailable)),
        );
      },
    );
  }

  test(
    'unsupported API and connection failures cannot be accepted as verified',
    () async {
      final unsupported = NightscoutTokenValidator(
        client: MockClient((_) async => http.Response('', 404)),
      );
      await expectLater(
        unsupported.validate(url: 'https://example.com', token: 'token'),
        throwsA(issue(NightscoutTokenIssue.unavailable)),
      );
      final offline = NightscoutTokenValidator(
        client: MockClient(
          (_) async =>
              throw TimeoutException('https://example.com/secret-token'),
        ),
      );
      try {
        await offline.validate(
          url: 'https://example.com',
          token: 'secret-token',
        );
        fail('Expected verification failure');
      } on NightscoutTokenValidationException catch (error) {
        expect(error.issue, NightscoutTokenIssue.unavailable);
        expect(error.toString(), isNot(contains('secret-token')));
        expect(error.toString(), isNot(contains('https://')));
      }
    },
  );
}
