import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_workflow_guard.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_plan_apply_test.dart' show localPlan;

Map<String, dynamic> scheduleValues() {
  final now = DateTime.now();
  return {
    'weekdays': [1, 2, 3, 4, 5, 6, 7],
    'startMinute': 17 * 60,
    'durationMinutes': 30,
    'confirmationMode': 'before',
    'previousDayMinute': 19 * 60,
    'validFrom': DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
    'validUntil': null,
  };
}

Map<String, dynamic> definitionValues() => {
  'name': 'Swimming',
  'percentagePre': 20,
  'percentagePost': 30,
  'durationMinutes': 30,
};
void main() {
  for (final type in [
    'createActivity',
    'updateActivity',
    'createActivitySchedule',
    'planActivity',
    'startActivity',
    'logActivity',
  ]) {
    test(
      '$type applies definition and recurrence atomically and idempotently',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final target =
            type == 'updateActivity' || type == 'createActivitySchedule';
        if (target) {
          await db.customStatement(
            "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Old',20,30)",
          );
        }
        final now = DateTime.now().millisecondsSinceEpoch;
        final values = <String, dynamic>{
          'schedule': scheduleValues(),
          if (type == 'createActivity' || type == 'updateActivity')
            'activity': definitionValues(),
          if ([
            'planActivity',
            'startActivity',
            'logActivity',
          ].contains(type)) ...{
            'activityId': null,
            'activity': definitionValues(),
            'startedAt': type == 'planActivity' ? now + 3600000 : now - 60000,
            if (type == 'planActivity') 'durationMinutes': 30,
            if (type == 'logActivity') 'endedAt': now,
          },
        };
        final plan = await localPlan(
          db,
          type,
          targetId: target ? 1 : null,
          values: values,
        );
        await ApplyFamilyPlanUseCase(db)('child', plan);
        await ApplyFamilyPlanUseCase(db)('child', plan);
        expect(
          (await db
                  .customSelect('SELECT outcome FROM family_plan_journal')
                  .getSingle())
              .data['outcome'],
          'applied',
        );
        expect(await db.select(db.activity).get(), hasLength(1));
        expect(await db.select(db.activitySchedule).get(), hasLength(1));
        expect(await db.select(db.activityOccurrence).get(), isNotEmpty);
      },
    );
  }
  test(
    'offline edit rejects stale definition and does not add its schedule',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Old',20,30)",
      );
      final plan = await localPlan(
        db,
        'updateActivity',
        targetId: 1,
        values: {'activity': definitionValues(), 'schedule': scheduleValues()},
      );
      await db.customStatement(
        "UPDATE activity SET name='Child edit' WHERE id=1",
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect((await db.select(db.activity).getSingle()).name, 'Child edit');
      expect(await db.select(db.activitySchedule).get(), isEmpty);
      expect(
        (await db
                .customSelect('SELECT reason FROM family_plan_journal')
                .getSingle())
            .data['reason'],
        'conflict',
      );
    },
  );
  for (final kind in ['running', 'recent', 'workflow']) {
    test('definition update blocked for $kind child activity', () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Old',20,30)",
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO activity_log(activity_id,started_at,ended_at) VALUES(1,?,?)',
        [now - 3600000, kind == 'running' ? null : now - 60000],
      );
      final guard = FamilyWorkflowGuard(db);
      if (kind == 'workflow') guard.blocked['activity'] = 1;
      final plan = await localPlan(
        db,
        'updateActivity',
        targetId: 1,
        values: {'activity': definitionValues(), 'schedule': null},
      );
      await ApplyFamilyPlanUseCase(db, workflowGuard: guard)('child', plan);
      expect((await db.select(db.activity).getSingle()).name, 'Old');
      expect(
        (await db
                .customSelect('SELECT outcome FROM family_plan_journal')
                .getSingle())
            .data['outcome'],
        'rejected',
      );
    });
  }
  test(
    'old completed target requests do not permanently lock definition',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Old',20,30)",
      );
      final old = DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch;
      await db.customStatement(
        "INSERT INTO activity_occurrence(activity_id,started_at,status,target_requested_at,action_at,confirmation_mode) VALUES(1,?,'recorded',?,?,'before')",
        [old, old, old],
      );
      final plan = await localPlan(
        db,
        'updateActivity',
        targetId: 1,
        values: {'activity': definitionValues(), 'schedule': null},
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect((await db.select(db.activity).getSingle()).name, 'Swimming');
      expect(
        (await db
                .customSelect('SELECT outcome FROM family_plan_journal')
                .getSingle())
            .data['outcome'],
        'applied',
      );
    },
  );
  test(
    'monitor starting during domain write rolls back edit and its schedule',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Old',20,30)",
      );
      final old = DateTime.now()
          .subtract(const Duration(days: 10))
          .millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO activity_log(activity_id,started_at,ended_at) VALUES(1,?,?)',
        [old, old + 60000],
      );
      final plan = await localPlan(
        db,
        'updateActivity',
        targetId: 1,
        values: {'activity': definitionValues(), 'schedule': scheduleValues()},
      );
      await ApplyFamilyPlanUseCase(
        db,
        workflowGuard: InterleavedActivityGuard(),
      )('child', plan);
      expect((await db.select(db.activity).getSingle()).name, 'Old');
      expect(await db.select(db.activitySchedule).get(), isEmpty);
      expect(
        (await db
                .customSelect('SELECT outcome FROM family_plan_journal')
                .getSingle())
            .data['outcome'],
        'rejected',
      );
    },
  );
}

class InterleavedActivityGuard extends FamilyWorkflowGuard {
  int reads = 0;
  @override
  bool contains(String kind, int id) => reads++ > 0;
}
