import 'package:clock/clock.dart';
import 'package:diabeatthis/common/family_sync/apply_family_plan_use_case.dart';
import 'package:diabeatthis/common/family_sync/family_plan_record_kind.dart';
import 'package:diabeatthis/common/family_sync/family_workflow_guard.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_plan_apply_test.dart' show localPlan;

final controlsNow = DateTime(2026, 11, 7, 12);
final trainingAt = DateTime(2026, 11, 11, 17);
Future<ActivityOccurrenceData> controlsSession(
  DatabaseImpl db, {
  bool near = false,
  bool recurring = false,
}) async {
  await db.customStatement(
    "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Training',20,30)",
  );
  final service = ActivityScheduleService(db);
  final at = near ? controlsNow.add(const Duration(minutes: 30)) : trainingAt;
  if (recurring) {
    await service.save(
      activityId: 1,
      weekdays: {at.weekday},
      startMinute: at.hour * 60 + at.minute,
      durationMinutes: 43,
      mode: 'before',
      validFrom: controlsNow,
    );
  } else {
    await service.planOnce(activityId: 1, start: at, durationMinutes: 43);
  }
  final row = await (db.select(
    db.activityOccurrence,
  )..where((r) => r.startedAt.equals(at.millisecondsSinceEpoch))).getSingle();
  await service.confirm(row.id);
  return (await (db.select(
    db.activityOccurrence,
  )..where((r) => r.id.equals(row.id))).getSingle());
}

class PreparingDuringApply extends ApplyFamilyPlanUseCase {
  PreparingDuringApply(super.db, this.guard, this.logId)
    : super(workflowGuard: guard);
  final FamilyWorkflowGuard guard;
  final int logId;
  @override
  Future<int?> applyDomainPlan(
    Map<String, dynamic> plan,
    Map<String, CatalogIngredient> catalog,
  ) async {
    final result = await super.applyDomainPlan(plan, catalog);
    guard.blocked['activity'] = logId;
    return result;
  }
}

void main() {
  test(
    'pending schedule result locks its schedule without colliding with other record kinds',
    () {
      final plan = {
        'type': 'createActivitySchedule',
        'status': 'pending',
        'targetId': 5,
        'resultId': 9,
      };
      expect(familyPlanLocksRecord(plan, 'activities', 5), true);
      expect(familyPlanLocksRecord(plan, 'activitySchedules', 9), true);
      expect(familyPlanLocksRecord(plan, 'activitySchedules', 5), false);
      expect(familyPlanLocksRecord(plan, 'activityOccurrences', 9), false);
    },
  );
  for (final type in ['skipActivity', 'moveActivity']) {
    test(
      'confirmed Nov11 session remains $type eligible while merely planned',
      () => withClock(Clock.fixed(controlsNow), () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final row = await controlsSession(db);
        final guard = FamilyWorkflowGuard(db);
        guard.record('activity', row.activityLogId, 'planned');
        await guard.writes;
        // Legacy early stamp is not evidence of preparation four days ahead.
        await db.customStatement(
          'UPDATE activity_occurrence SET target_requested_at=? WHERE id=?',
          [controlsNow.millisecondsSinceEpoch, row.id],
        );
        final plan = await localPlan(
          db,
          type,
          targetId: row.id,
          values: type == 'skipActivity'
              ? {}
              : {
                  'startedAt': trainingAt
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch,
                },
        );
        await ApplyFamilyPlanUseCase(db, workflowGuard: guard)('child', plan);
        expect(
          (await db
                  .customSelect('SELECT outcome FROM family_plan_journal')
                  .getSingle())
              .data['outcome'],
          'applied',
        );
        if (type == 'skipActivity') {
          expect(
            (await (db.select(
              db.activityOccurrence,
            )..where((r) => r.id.equals(row.id))).getSingle()).status,
            'skipped',
          );
          expect(await db.select(db.activityLog).get(), isEmpty);
        }
      }),
    );
    for (final reason in ['preparing', 'target', 'interleaving']) {
      test(
        '$type rejects $reason and retains child session',
        () => withClock(Clock.fixed(controlsNow), () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          addTearDown(db.close);
          final row = await controlsSession(db, near: reason == 'target');
          final guard = FamilyWorkflowGuard(db);
          if (reason == 'preparing') {
            guard.record('activity', row.activityLogId, 'preparing');
            await guard.writes;
          }
          if (reason == 'target') {
            await db.customStatement(
              'UPDATE activity_occurrence SET target_requested_at=? WHERE id=?',
              [controlsNow.millisecondsSinceEpoch, row.id],
            );
          }
          final plan = await localPlan(
            db,
            type,
            targetId: row.id,
            values: type == 'skipActivity'
                ? {}
                : {
                    'startedAt': trainingAt
                        .add(const Duration(hours: 1))
                        .millisecondsSinceEpoch,
                  },
          );
          final useCase = reason == 'interleaving'
              ? PreparingDuringApply(db, guard, row.activityLogId!)
              : ApplyFamilyPlanUseCase(db, workflowGuard: guard);
          await useCase('child', plan);
          expect(
            (await db
                    .customSelect('SELECT outcome FROM family_plan_journal')
                    .getSingle())
                .data['outcome'],
            'rejected',
          );
          expect(
            (await (db.select(
              db.activityOccurrence,
            )..where((r) => r.id.equals(row.id))).getSingle()).status,
            'planned',
          );
          expect(
            (await db.select(db.activityLog).getSingle()).id,
            row.activityLogId,
          );
        }),
      );
    }
  }
  test(
    'disable preserves running session and history, cancels future and journals prompts',
    () => withClock(Clock.fixed(controlsNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final row = await controlsSession(db, recurring: true);
      final old = controlsNow
          .subtract(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      await db.customStatement(
        'INSERT INTO activity_log(activity_id,started_at) VALUES(1,?)',
        [old],
      );
      final active = await (db.select(
        db.activityLog,
      )..where((r) => r.startedAt.equals(old))).getSingle();
      await db.customStatement(
        "INSERT INTO activity_occurrence(schedule_id,activity_id,started_at,action_at,confirmation_mode,status,activity_log_id) VALUES(?,1,?,?,'before','planned',?)",
        [row.scheduleId, old, old, active.id],
      );
      final future =
          await (db.select(db.activityOccurrence)..where(
                (r) => r.startedAt.isBiggerThanValue(
                  controlsNow.millisecondsSinceEpoch,
                ),
              ))
              .get();
      final plan = await localPlan(
        db,
        'setActivityScheduleEnabled',
        targetId: row.scheduleId,
        values: {
          'enabled': false,
          'effectiveFrom': controlsNow.millisecondsSinceEpoch,
        },
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect((await db.select(db.activitySchedule).getSingle()).enabled, false);
      expect(await db.select(db.activityOccurrence).get(), hasLength(1));
      expect((await db.select(db.activityLog).getSingle()).id, active.id);
      final notifications = await db
          .customSelect(
            'SELECT occurrence_id,cleared FROM family_plan_notification_cancellations',
          )
          .get();
      expect(
        notifications.map((r) => r.data['occurrence_id']).toSet(),
        future.map((r) => r.id).toSet(),
      );
      expect(notifications.every((r) => r.data['cleared'] == 0), true);
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect(await db.select(db.activityOccurrence).get(), hasLength(1));
      final enable = await localPlan(
        db,
        'setActivityScheduleEnabled',
        targetId: row.scheduleId,
        values: {
          'enabled': true,
          'effectiveFrom': controlsNow.millisecondsSinceEpoch,
        },
      );
      enable['id'] = 'b' * 32;
      await ApplyFamilyPlanUseCase(db)('child', enable);
      expect((await db.select(db.activitySchedule).getSingle()).enabled, true);
      expect(
        (await db.select(db.activityOccurrence).get()).length,
        greaterThan(1),
      );
    }),
  );
  test(
    'disable rejects monitor starting during deletion and restores all rows',
    () => withClock(Clock.fixed(controlsNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final row = await controlsSession(db, recurring: true);
      final guard = FamilyWorkflowGuard(db);
      final plan = await localPlan(
        db,
        'setActivityScheduleEnabled',
        targetId: row.scheduleId,
        values: {
          'enabled': false,
          'effectiveFrom': controlsNow.millisecondsSinceEpoch,
        },
      );
      await PreparingDuringApply(db, guard, row.activityLogId!)('child', plan);
      expect((await db.select(db.activitySchedule).getSingle()).enabled, true);
      expect(await db.select(db.activityLog).get(), hasLength(1));
      expect(
        await db
            .customSelect(
              'SELECT * FROM family_plan_notification_cancellations',
            )
            .get(),
        isEmpty,
      );
      expect(
        (await db
                .customSelect('SELECT outcome FROM family_plan_journal')
                .getSingle())
            .data['outcome'],
        'rejected',
      );
    }),
  );
  test(
    'schedule cutoff ahead of child clock rejects without deleting sessions',
    () => withClock(Clock.fixed(controlsNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final row = await controlsSession(db, recurring: true);
      final plan = await localPlan(
        db,
        'setActivityScheduleEnabled',
        targetId: row.scheduleId,
        values: {
          'enabled': false,
          'effectiveFrom': controlsNow
              .add(const Duration(seconds: 20))
              .millisecondsSinceEpoch,
        },
      );
      await ApplyFamilyPlanUseCase(db)('child', plan);
      expect((await db.select(db.activitySchedule).getSingle()).enabled, true);
      expect(await db.select(db.activityLog).get(), hasLength(1));
      expect(
        (await db
                .customSelect('SELECT outcome FROM family_plan_journal')
                .getSingle())
            .data['outcome'],
        'rejected',
      );
    }),
  );
  test(
    'schedule original session is rechecked when clock crosses its start during deletion',
    () async {
      var now = controlsNow;
      await withClock(Clock(() => now), () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final row = await controlsSession(db, recurring: true);
        now = trainingAt.subtract(const Duration(seconds: 5));
        final plan = await localPlan(
          db,
          'setActivityScheduleEnabled',
          targetId: row.scheduleId,
          values: {
            'enabled': false,
            'effectiveFrom': now.millisecondsSinceEpoch,
          },
        );
        plan['claimUntil'] = trainingAt
            .add(const Duration(minutes: 1))
            .millisecondsSinceEpoch;
        await ClockCrossingApply(
          db,
          () => now = trainingAt.add(const Duration(seconds: 1)),
        )('child', plan);
        expect(
          (await db.select(db.activitySchedule).getSingle()).enabled,
          true,
        );
        expect(await db.select(db.activityLog).get(), hasLength(1));
        expect(
          (await db
                  .customSelect('SELECT outcome FROM family_plan_journal')
                  .getSingle())
              .data['outcome'],
          'rejected',
        );
      });
    },
  );
}

class ClockCrossingApply extends ApplyFamilyPlanUseCase {
  ClockCrossingApply(super.db, this.advance);
  final void Function() advance;
  @override
  Future<int?> applyDomainPlan(
    Map<String, dynamic> plan,
    Map<String, CatalogIngredient> catalog,
  ) async {
    final result = await super.applyDomainPlan(plan, catalog);
    advance();
    return result;
  }
}
