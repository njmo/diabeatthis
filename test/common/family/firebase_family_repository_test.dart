import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family/firebase_family_repository.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'QR redemption passes only invite and secret, never identity, role or recipients',
    () async {
      final calls = <String>[];
      final repository = FirebaseFamilyRepository(
        AuthenticatedCallableTransport(
          client: MockClient((request) async {
            calls.add(request.url.path);
            expect(jsonDecode(request.body), {
              'data': {'inviteId': 'i' * 43, 'token': 't' * 43},
            });
            return http.Response('{"result":{"pending":true}}', 200);
          }),
          projectId: 'test',
          currentUid: () => 'parent',
          identity: () async =>
              const CallableIdentity('parent', 'token', 'app-check'),
        ),
      );
      addTearDown(repository.dispose);
      await repository.requestJoin(
        jsonEncode({
          'v': 1,
          'kind': 'diabeatthis-family',
          'inviteId': 'i' * 43,
          'token': 't' * 43,
        }),
      );
      expect(calls, ['/requestFamilyJoin']);
      await expectLater(
        repository.requestJoin(
          '{"v":1,"kind":"diabeatthis-family","inviteId":"i","token":"t","familyId":"victim"}',
        ),
        throwsA(isA<CallableFailure>()),
      );
      await expectLater(
        repository.createInvitation(SetupDeviceMode.caregiver),
        throwsA(isA<CallableFailure>()),
      );
      expect(calls.length, 1);
    },
  );
}
