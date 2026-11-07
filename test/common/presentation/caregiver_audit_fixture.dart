import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_plan_submission_store.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:http/testing.dart';

import 'family_collection_fixtures.dart';

class CaregiverAuditFixture {
  CaregiverAuditFixture() {
    family =
        FamilyPlanningController(
            transport,
            () => uid,
            FamilyPlanSubmissionStore(db),
          )
          ..uid = uid
          ..owner = 'child'
          ..source = 'child-source'
          ..complete = true;
    for (final row in familyCollectionFixtures(status: 'eaten')) {
      family.rows['${row['kind']}/${row['id']}'] = row;
    }
  }
  String? uid = 'parent';
  final db = DatabaseImpl(NativeDatabase.memory());
  late final transport = AuthenticatedCallableTransport(
    client: MockClient(
      (_) async => throw StateError('No backend calls expected'),
    ),
    projectId: 'test',
    currentUid: () => uid,
    identity: () async => const CallableIdentity('parent', 'token', 'check'),
  );
  late final FamilyPlanningController family;
  Future<void> close() async {
    if (!family.disposed) family.dispose();
    transport.client.close();
    await db.close();
  }
}
