import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_workflow_guard.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_plan_apply_test.dart' show localPlan;

class InterleavedActivityPlan extends ApplyFamilyPlanUseCase {
  InterleavedActivityPlan(super.db, {required FamilyWorkflowGuard guard})
    : super(workflowGuard: guard);
  @override
  Future<int?> applyDomainPlan(
    Map<String, dynamic> plan,
    Map<String, CatalogIngredient> catalogIngredients,
  ) async {
    final id = await super.applyDomainPlan(plan, catalogIngredients);
    workflowGuard!.blocked['activity'] = 999;
    return id;
  }
}

void main() {
  Future<DatabaseImpl> database() async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO activity(name,percentage_pre,percentage_post,duration_minutes) VALUES('Walk',10,10,30)",
    );
    return db;
  }

  test(
    'child starts once and rejects a second start without changing the first',
    () async {
      final db = await database();
      final start = DateTime.now().millisecondsSinceEpoch;
      final plan = await localPlan(
        db,
        'startActivity',
        values: {'activityId': 1, 'startedAt': start},
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect(await db.select(db.activityLog).get(), hasLength(1));
      expect((await db.select(db.activityLog).getSingle()).endedAt, isNull);
      final second = await localPlan(
        db,
        'startActivity',
        values: {'activityId': 1, 'startedAt': start},
      );
      second['id'] = 'f' * 32;
      await ApplyFamilyPlanUseCase(db)('child', second);
      expect(await db.select(db.activityLog).get(), hasLength(1));
      final rejection = await db
          .customSelect(
            "SELECT outcome,reason FROM family_plan_journal WHERE operation_id='${second['id']}'",
          )
          .getSingle();
      expect(rejection.read<String>('outcome'), 'rejected');
      expect(rejection.read<String>('reason'), 'activity-running');
    },
  );
  test(
    'a workflow appearing during application rolls back the new log',
    () async {
      final db = await database();
      final plan = await localPlan(
        db,
        'startActivity',
        values: {
          'activityId': 1,
          'startedAt': DateTime.now().millisecondsSinceEpoch,
        },
      );
      await InterleavedActivityPlan(db, guard: FamilyWorkflowGuard(db))(
        'child',
        plan,
      );
      expect(await db.select(db.activityLog).get(), isEmpty);
      final journal = await db
          .customSelect('SELECT outcome,reason FROM family_plan_journal')
          .getSingle();
      expect(journal.read<String>('outcome'), 'rejected');
      expect(journal.read<String>('reason'), 'activity-running');
    },
  );
  test(
    'historical command creates a finished log and never activates a monitor',
    () async {
      final db = await database();
      final now = DateTime.now().millisecondsSinceEpoch;
      final plan = await localPlan(
        db,
        'logActivity',
        values: {
          'activityId': 1,
          'startedAt': now - 3600000,
          'endedAt': now - 1800000,
        },
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      final row = await db.select(db.activityLog).getSingle();
      expect(row.endedAt, now - 1800000);
      expect(await db.activityDao.getActiveActivityLogOrNull(), isNull);
    },
  );
}
