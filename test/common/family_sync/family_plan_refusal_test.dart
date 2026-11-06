import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'definitive callable refusal releases parent send intent, transient failure retains it',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      var transient = false;
      final transport = AuthenticatedCallableTransport(
        client: MockClient(
          (_) async => http.Response(
            transient
                ? '{"error":{"status":"UNAVAILABLE"}}'
                : '{"error":{"status":"FAILED_PRECONDITION"}}',
            transient ? 503 : 400,
          ),
        ),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final store = FamilyPlanSubmissionStore(db);
      final controller = FamilyPlanningController(
        transport,
        () => 'parent',
        store,
      );
      addTearDown(controller.dispose);
      final draft = {'id': 'a' * 32, 'sourceId': 'b' * 32};
      await store.reserve('parent', draft);
      await expectLater(
        controller.sendReserved('parent', draft),
        throwsA(isA<CallableFailure>()),
      );
      expect(await store.pending('parent'), isNull);
      transient = true;
      await store.reserve('parent', draft);
      await expectLater(
        controller.sendReserved('parent', draft),
        throwsA(isA<CallableFailure>()),
      );
      expect(await store.pending('parent'), draft);
    },
  );
}
