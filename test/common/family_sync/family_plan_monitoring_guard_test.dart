import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_workflow_guard.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'family_plan_apply_test.dart' show localPlan, seedPlanIngredient;

void main() {
  test(
    'actual monitoring blocks caregiver edit even if meal is still planned',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      final create = await localPlan(db, 'createMeal');
      await ApplyFamilyPlanUseCase(db)('child', create);
      final edit = await localPlan(db, 'updateMeal', targetId: 1);
      edit['id'] = 'f' * 32;
      final guard = FamilyWorkflowGuard(db);
      guard.record('meal', 1, 'preparing');
      // The live guard is immediate, before asynchronous projection persistence.
      expect(guard.contains('meal', 1), true);
      await guard.writes;
      await ApplyFamilyPlanUseCase(db, workflowGuard: guard)('child', edit);
      expect(
        (await db
                .customSelect(
                  "SELECT outcome FROM family_plan_journal WHERE outcome='rejected'",
                )
                .getSingle())
            .read<String>('outcome'),
        'rejected',
      );
      expect((await db.select(db.meal).getSingle()).status, 'planned');
      guard.record('meal', 1, 'planned');
      await guard.writes;
      expect(await guard.persisted('meal', 1), true);
      guard.record('meal', null, 'idle');
      await guard.writes;
      expect(await guard.persisted('meal', 1), false);
    },
  );
  test(
    'independent mirror cannot publish a newly created result before its cloud lock is bound',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seedPlanIngredient(db);
      await ApplyFamilyPlanUseCase(db)(
        'child',
        await localPlan(db, 'createMeal'),
      );
      final transport = AuthenticatedCallableTransport(
        client: MockClient(
          (_) async => throw StateError('Unexpected publication'),
        ),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => throw StateError('Unexpected identity'),
      );
      expect(
        await PublishFamilyMirrorUseCase(
          outbox: FamilyMirrorOutbox(db),
          transport: transport,
          currentUid: () => 'child',
        )(),
        0,
      );
      expect(
        (await FamilyMirrorOutbox(db).pending()).any((r) => r.kind == 'meals'),
        true,
      );
    },
  );
  test('planned activity stays editable until preparation actually begins', () {
    final guard = FamilyWorkflowGuard();
    guard.record('activity', 7, 'planned');
    expect(guard.contains('activity', 7), false);
    guard.record('activity', 7, 'preparing');
    expect(guard.contains('activity', 7), true);
    guard.record('activity', null, 'unavailable');
    expect(guard.contains('activity', 7), true);
    guard.record('activity', null, 'idle');
    expect(guard.contains('activity', 7), false);
  });
}
