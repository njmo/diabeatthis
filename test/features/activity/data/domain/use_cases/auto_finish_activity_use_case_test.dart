import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/auto_finish_activity_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 28, 17);
  test(
    'no writes before the deadline or for an activity without a time limit',
    () async {
      final useCase = AutoFinishActivityUseCase(
        now: () => start.add(const Duration(minutes: 59)),
        finishIfOpen: (_, _, _) => throw StateError('Must not write'),
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        false,
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: null),
        false,
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 0),
        false,
      );
    },
  );
  test(
    'late restart saves the deadline once and preserves unrelated log data',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, start);
      final useCase = AutoFinishActivityUseCase(
        now: () => start.add(const Duration(hours: 4)),
        finishIfOpen: db.activityDao.finishActivityLogIfOpen,
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        true,
      );
      var log = await db.activityDao.getActivityLogById(1);
      expect(
        log.endedAt,
        start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
      expect(log.notes, 'Keep this note');
      expect(log.intensity, 'high');
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        false,
      );
      log = await db.activityDao.getActivityLogById(1);
      expect(
        log.endedAt,
        start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      );
    },
  );
  test(
    'a manual finish or changed start cannot be overwritten by a late timer',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await seed(db, start);
      final useCase = AutoFinishActivityUseCase(
        now: () => start.add(const Duration(hours: 4)),
        finishIfOpen: db.activityDao.finishActivityLogIfOpen,
      );
      final manual = start.add(const Duration(minutes: 35));
      await db.activityDao.updateActivityLog(
        ActivityLogCompanion(
          id: const Value(1),
          activityId: const Value(1),
          startedAt: Value(start.millisecondsSinceEpoch),
          endedAt: Value(manual.millisecondsSinceEpoch),
        ),
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        false,
      );
      expect(
        (await db.activityDao.getActivityLogById(1)).endedAt,
        manual.millisecondsSinceEpoch,
      );
      final moved = start.add(const Duration(minutes: 15));
      await db.activityDao.updateActivityLog(
        ActivityLogCompanion(
          id: const Value(1),
          activityId: const Value(1),
          startedAt: Value(moved.millisecondsSinceEpoch),
          endedAt: const Value(null),
        ),
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        false,
      );
      expect((await db.activityDao.getActivityLogById(1)).endedAt, isNull);
      await db.activityDao.removeActivityLog(
        const ActivityLogCompanion(id: Value(1)),
      );
      expect(
        await useCase(activityLogId: 1, startsAt: start, durationMinutes: 60),
        false,
      );
    },
  );
}

Future<void> seed(DatabaseImpl db, DateTime start) async {
  await db.activityDao.insertActivity(
    ActivityCompanion.insert(
      name: 'Jujitsu',
      percentagePre: 80,
      percentagePost: 80,
      durationMinutes: const Value(60),
    ),
  );
  await db.activityDao.insertActivityLog(
    ActivityLogCompanion.insert(
      activityId: 1,
      startedAt: start.millisecondsSinceEpoch,
      notes: const Value('Keep this note'),
      intensity: const Value('high'),
    ),
  );
}
