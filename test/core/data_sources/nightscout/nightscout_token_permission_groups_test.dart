import 'dart:convert';

import 'package:diabeatthis/core/data_sources/nightscout/nightscout_token_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  Matcher issue(NightscoutTokenIssue expected) =>
      isA<NightscoutTokenValidationException>().having(
        (error) => error.issue,
        'issue',
        expected,
      );

  Map<String, dynamic> identity(Object groups) => {
    'token': 'signed-jwt',
    'permissionGroups': groups,
  };
  const readOnlySummary = {
    'status': 200,
    'result': {
      'apiPermissions': {'treatments': 'r'},
    },
  };

  test(
    'split careportal/readable roles are verified through read-only permission checks when status reports only r',
    () async {
      final requests = <http.Request>[];
      final validator = NightscoutTokenValidator(
        client: MockClient((request) async {
          requests.add(request);
          expect(request.method, 'GET');
          expect(request.body, isEmpty);
          if (request.url.pathSegments.contains('request')) {
            return http.Response(
              jsonEncode(
                identity([
                  ['api:treatments:create'],
                  ['*:*:read'],
                  [],
                ]),
              ),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer signed-jwt');
          if (request.url.path.endsWith('/status')) {
            return http.Response(jsonEncode(readOnlySummary), 200);
          }
          expect(
            request.url.pathSegments.last,
            isIn(['api:treatments:read', 'api:treatments:create']),
          );
          return http.Response('{"check":true}', 200);
        }),
      );
      await validator.validate(
        url: 'https://example.com/nightscout/?token=old-token',
        token: 'access-token',
      );
      expect(requests, hasLength(4));
      expect(requests.skip(2).map((request) => request.url.pathSegments.last), [
        'api:treatments:read',
        'api:treatments:create',
      ]);
      expect(
        requests
            .skip(2)
            .every(
              (request) => request.url.path.startsWith(
                '/nightscout/api/v2/authorization/debug/check/',
              ),
            ),
        isTrue,
      );
      expect(
        requests.every((request) => request.url.queryParameters.isEmpty),
        isTrue,
      );
    },
  );

  test('an empty writable role still cannot authorize writes', () async {
    var requests = 0;
    final validator = NightscoutTokenValidator(
      client: MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode(
            requests == 1
                ? identity([
                    ['*:*:read'],
                    [],
                  ])
                : readOnlySummary,
          ),
          200,
        );
      }),
    );
    await expectLater(
      validator.validate(url: 'https://example.com', token: 'token'),
      throwsA(issue(NightscoutTokenIssue.treatmentAccess)),
    );
    expect(requests, 2);
  });

  for (final deniedAction in ['read', 'create']) {
    test('permission hints cannot bypass denial of $deniedAction', () async {
      final validator = NightscoutTokenValidator(
        client: MockClient((request) async {
          if (request.url.pathSegments.contains('request')) {
            return http.Response(
              jsonEncode(
                identity([
                  ['*'],
                ]),
              ),
              200,
            );
          }
          if (request.url.path.endsWith('/status')) {
            return http.Response(jsonEncode(readOnlySummary), 200);
          }
          return request.url.pathSegments.last == 'api:treatments:$deniedAction'
              ? http.Response('{"status":401}', 401)
              : http.Response('{"check":true}', 200);
        }),
      );
      await expectLater(
        validator.validate(url: 'https://example.com', token: 'token'),
        throwsA(issue(NightscoutTokenIssue.treatmentAccess)),
      );
    });
  }

  for (final permissions in [
    'api:*:create',
    'api:treatments:*',
    '*',
    'api:treatments:read,create',
  ]) {
    test(
      'permission hint $permissions still requires explicit server approval',
      () async {
        var checks = 0;
        final validator = NightscoutTokenValidator(
          client: MockClient((request) async {
            if (request.url.pathSegments.contains('request')) {
              return http.Response(
                jsonEncode(
                  identity([
                    [permissions],
                  ]),
                ),
                200,
              );
            }
            if (request.url.path.endsWith('/status')) {
              return http.Response(jsonEncode(readOnlySummary), 200);
            }
            checks++;
            return http.Response('{"check":true}', 200);
          }),
        );
        await validator.validate(url: 'https://example.com', token: 'token');
        expect(checks, 2);
      },
    );
  }

  for (final status in [404, 503]) {
    test(
      'unavailable diagnostic endpoint $status cannot be accepted as permission',
      () async {
        final validator = NightscoutTokenValidator(
          client: MockClient((request) async {
            if (request.url.pathSegments.contains('request')) {
              return http.Response(
                jsonEncode(
                  identity([
                    ['api:treatments:create'],
                  ]),
                ),
                200,
              );
            }
            if (request.url.path.endsWith('/status')) {
              return http.Response(jsonEncode(readOnlySummary), 200);
            }
            return http.Response('', status);
          }),
        );
        await expectLater(
          validator.validate(url: 'https://example.com', token: 'token'),
          throwsA(issue(NightscoutTokenIssue.unavailable)),
        );
      },
    );
  }

  test(
    'a generic public response cannot stand in for an explicit permission check',
    () async {
      final validator = NightscoutTokenValidator(
        client: MockClient((request) async {
          if (request.url.pathSegments.contains('request')) {
            return http.Response(
              jsonEncode(
                identity([
                  ['api:treatments:create'],
                ]),
              ),
              200,
            );
          }
          return http.Response(jsonEncode(readOnlySummary), 200);
        }),
      );
      await expectLater(
        validator.validate(url: 'https://example.com', token: 'token'),
        throwsA(issue(NightscoutTokenIssue.unavailable)),
      );
    },
  );
}
