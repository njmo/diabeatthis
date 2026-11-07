import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/call_family_activity_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final function in [
    'registerFamilyMirror',
    'fetchFamilyPlans',
    'claimFamilyPlan',
  ]) {
    test(
      '$function retries the exact legacy request only for definitive INVALID_ARGUMENT',
      () async {
        final requests = <Map>[];
        final client = MockClient((request) async {
          requests.add((jsonDecode(request.body) as Map)['data'] as Map);
          return requests.length == 1
              ? http.Response(
                  jsonEncode({
                    'error': {'status': 'INVALID_ARGUMENT'},
                  }),
                  400,
                )
              : http.Response(
                  jsonEncode({
                    'result': {'ok': true},
                  }),
                  200,
                );
        });
        addTearDown(client.close);
        final transport = AuthenticatedCallableTransport(
          client: client,
          projectId: 'test',
          currentUid: () => 'child',
          identity: () async =>
              const CallableIdentity('child', 'token', 'appcheck'),
        );
        final response = await callFamilyActivityProtocol(
          transport: transport,
          name: function,
          data: {'sourceId': 'source'},
          uid: 'child',
          permitted: () async => true,
        );
        expect(response['ok'], true);
        expect(requests, [
          {'sourceId': 'source', 'activityCommandsVersion': 1},
          {'sourceId': 'source'},
        ]);
      },
    );
  }
  for (final status in [
    'PERMISSION_DENIED',
    'FAILED_PRECONDITION',
    'INTERNAL',
  ]) {
    test('$status never downgrades or resends', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'error': {'status': status},
          }),
          status == 'INTERNAL' ? 500 : 403,
        );
      });
      addTearDown(client.close);
      final transport = AuthenticatedCallableTransport(
        client: client,
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async =>
            const CallableIdentity('child', 'token', 'appcheck'),
      );
      await expectLater(
        callFamilyActivityProtocol(
          transport: transport,
          name: 'fetchFamilyPlans',
          data: {},
          uid: 'child',
          permitted: () async => true,
        ),
        throwsA(isA<CallableFailure>()),
      );
      expect(calls, 1);
    });
  }
}
