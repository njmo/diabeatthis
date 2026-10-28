import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/update_completed_activity_times_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 10, 28, 17),
      end = DateTime(2026, 10, 28, 21),
      now = DateTime(2026, 10, 28, 22);
  late DatabaseImpl db;
  late UpdateCompletedActivityTimesUseCase edit;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
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
        endedAt: Value(end.millisecondsSinceEpoch),
        intensity: const Value('high'),
        notes: const Value('Keep the note'),
        isSynced: const Value(true),
      ),
    );
    edit = UpdateCompletedActivityTimesUseCase(
      now: () => now,
      updateIfUnchanged: db.activityDao.updateCompletedActivityLogTimes,
    );
  });
  tearDown(() async => db.close());
  test(
    'corrects completed times while preserving the log identity, details and activity plan',
    () async {
      final corrected = DateTime(2026, 10, 28, 18);
      await edit(
        id: 1,
        expectedStart: start,
        expectedEnd: end,
        startedAt: start,
        endedAt: corrected,
      );
      final log = await db.activityDao.getActivityLogById(1);
      expect(log.startedAt, start.millisecondsSinceEpoch);
      expect(log.endedAt, corrected.millisecondsSinceEpoch);
      expect(log.activityId, 1);
      expect(log.intensity, 'high');
      expect(log.notes, 'Keep the note');
      expect(log.isSynced, false);
      expect((await db.activityDao.getActivityById(1)).durationMinutes, 60);
    },
  );
  test(
    'invalid or future intervals do not change the saved timestamps',
    () async {
      for (final invalidEnd in [
        start,
        start.subtract(const Duration(seconds: 1)),
        now.add(const Duration(seconds: 1)),
      ]) {
        await expectLater(
          edit(
            id: 1,
            expectedStart: start,
            expectedEnd: end,
            startedAt: start,
            endedAt: invalidEnd,
          ),
          throwsArgumentError,
        );
      }
      expect(
        (await db.activityDao.getActivityLogById(1)).endedAt,
        end.millisecondsSinceEpoch,
      );
    },
  );
  test(
    'stale forms, reopened and deleted logs cannot overwrite a newer state',
    () async {
      final corrected = start.add(const Duration(hours: 1));
      await edit(
        id: 1,
        expectedStart: start,
        expectedEnd: end,
        startedAt: start,
        endedAt: corrected,
      );
      await expectLater(
        edit(
          id: 1,
          expectedStart: start,
          expectedEnd: end,
          startedAt: start,
          endedAt: end,
        ),
        throwsStateError,
      );
      await db.activityDao.updateActivityLog(
        ActivityLogCompanion(
          id: const Value(1),
          activityId: const Value(1),
          startedAt: Value(start.millisecondsSinceEpoch),
          endedAt: const Value(null),
        ),
      );
      await expectLater(
        edit(
          id: 1,
          expectedStart: start,
          expectedEnd: corrected,
          startedAt: start,
          endedAt: end,
        ),
        throwsStateError,
      );
      expect((await db.activityDao.getActivityLogById(1)).endedAt, isNull);
      await db.activityDao.removeActivityLog(
        const ActivityLogCompanion(id: Value(1)),
      );
      await expectLater(
        edit(
          id: 1,
          expectedStart: start,
          expectedEnd: corrected,
          startedAt: start,
          endedAt: end,
        ),
        throwsStateError,
      );
    },
  );
  test('supports correcting dates across midnight', () async {
    final previous = DateTime(2026, 10, 27, 23, 30),
        afterMidnight = DateTime(2026, 10, 28, 0, 30);
    await edit(
      id: 1,
      expectedStart: start,
      expectedEnd: end,
      startedAt: previous,
      endedAt: afterMidnight,
    );
    final log = await db.activityDao.getActivityLogById(1);
    expect(log.startedAt, previous.millisecondsSinceEpoch);
    expect(log.endedAt, afterMidnight.millisecondsSinceEpoch);
  });
}
