import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
