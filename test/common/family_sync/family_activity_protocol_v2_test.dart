import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/call_family_activity_protocol.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final supported in [2, 1, 0]) {
    test('v2 safely negotiates backend capability $supported', () async {
      final versions = <int>[];
      final client = MockClient((request) async {
        final data = (jsonDecode(request.body) as Map)['data'] as Map;
        final version = data['activityCommandsVersion'] as int? ?? 0;
        versions.add(version);
        return version > supported
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
      await callFamilyActivityProtocol(
        transport: transport,
        name: 'fetchFamilyPlans',
        data: {},
        uid: 'child',
        permitted: () async => true,
        activityCommandsVersion: 2,
      );
      expect(
        versions,
        supported == 2
            ? [2]
            : supported == 1
            ? [2, 1]
            : [2, 1, 0],
      );
    });
  }
}
