import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final example in [
    (
      function: 'sendFamilyChatMessage',
      status: 400,
      code: 'FAILED_PRECONDITION',
      reason: 'chat-send-outcome-unknown',
      expected: 'chat-send-outcome-unknown',
    ),
    (
      function: 'sendFamilyChatMessage',
      status: 401,
      code: 'FAILED_PRECONDITION',
      reason: 'chat-send-outcome-unknown',
      expected: null,
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 400,
      code: 'FAILED_PRECONDITION',
      reason: 'chat-send-outcome-unknown',
      expected: null,
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 401,
      code: 'NOT_FOUND',
      reason: 'consumption-request-expired',
      expected: null,
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 404,
      code: 'NOT_FOUND',
      reason: 'consumption-request-expired',
      expected: 'consumption-request-expired',
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 404,
      code: 'NOT_FOUND',
      reason: 'consumption-request-unavailable',
      expected: 'consumption-request-unavailable',
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 500,
      code: 'NOT_FOUND',
      reason: 'consumption-request-expired',
      expected: null,
    ),
    (
      function: 'fetchFamilyChatMessageStates',
      status: 404,
      code: 'NOT_FOUND',
      reason: 'consumption-request-expired',
      expected: null,
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 403,
      code: 'PERMISSION_DENIED',
      reason: 'consumption-request-expired',
      expected: null,
    ),
    (
      function: 'claimFamilyChatTreatment',
      status: 404,
      code: 'NOT_FOUND',
      reason: 'unknown-private-detail',
      expected: null,
    ),
  ]) {
    test(
      'definitive reason is restricted to exact endpoint and status: $example',
      () async {
        final transport = AuthenticatedCallableTransport(
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'status': example.code,
                  'details': {'reason': example.reason},
                },
              }),
              example.status,
            ),
          ),
          projectId: 'test',
          identity: () async =>
              const CallableIdentity('child', 'token', 'attestation'),
          currentUid: () => 'child',
        );
        await expectLater(
          transport.call(example.function, {}),
          throwsA(
            isA<CallableFailure>().having(
              (value) => value.rejectionReason,
              'whitelisted reason',
              example.expected,
            ),
          ),
        );
      },
    );
  }
  test(
    'calls include Google ID token and App Check without accepting arbitrary function names',
    () async {
      var calls = 0;
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          calls++;
          expect(request.headers['Authorization'], 'Bearer google-token');
          expect(request.headers['X-Firebase-AppCheck'], 'attestation');
          expect(jsonDecode(request.body), {'data': <String, dynamic>{}});
          return http.Response('{"result":{"members":[],"pending":null}}', 200);
        }),
        projectId: 'test-project',
        identity: () async =>
            const CallableIdentity('parent', 'google-token', 'attestation'),
        currentUid: () => 'parent',
      );
      await transport.call('getFamilyStatus', {});
      await expectLater(
        transport.call('sendNotificationToUser', {'uid': 'victim'}),
        throwsA(isA<CallableFailure>()),
      );
      expect(calls, 1);
    },
  );
  test('responses from previous Google account are discarded', () async {
    var uid = 'old-parent';
    final transport = AuthenticatedCallableTransport(
      client: MockClient((_) async {
        uid = 'new-parent';
        return http.Response(
          '{"result":{"members":[{"id":"old-child"}]}}',
          200,
        );
      }),
      projectId: 'test',
      identity: () async =>
          const CallableIdentity('old-parent', 'token', 'app-token'),
      currentUid: () => uid,
    );
    await expectLater(
      transport.call('getFamilyStatus', {}),
      throwsA(isA<CallableFailure>()),
    );
  });
  test(
    'chat registration and history use the configured HTTPS project',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(
          request.url.host,
          'europe-west1-test-project.cloudfunctions.net',
        );
        expect(request.headers['Authorization'], 'Bearer google-token');
        expect(request.headers['X-Firebase-AppCheck'], 'attestation');
        paths.add(request.url.path);
        return http.Response('{"result":{}}', 200);
      });
      addTearDown(client.close);
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: 'test-project',
        identity: () async =>
            const CallableIdentity('parent', 'google-token', 'attestation'),
        currentUid: () => 'parent',
      );
      await transport.call('registerFamilyChatNotifications', {});
      await transport.call('clearFamilyChatHistory', {});
      expect(paths, [
        '/registerFamilyChatNotifications',
        '/clearFamilyChatHistory',
      ]);
    },
  );
  test('missing App Check blocks the request before network access', () async {
    final transport = AuthenticatedCallableTransport(
      client: MockClient((_) async => throw StateError('Must not call')),
      projectId: 'test',
      identity: () async => const CallableIdentity('parent', 'token', ''),
      currentUid: () => 'parent',
    );
    await expectLater(
      transport.call('getFamilyStatus', {}),
      throwsA(isA<CallableFailure>()),
    );
  });
}
