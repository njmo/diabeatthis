import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/auto_finish_activity_use_case.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/end_activity_entry_use_case.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_summary_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final start = DateTime(2026, 11, 3, 10);
  final end = start.add(const Duration(minutes: 30));
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    await db.activityDao.insertActivity(
      ActivityCompanion.insert(
        name: 'Running',
        percentagePre: 80,
        percentagePost: 80,
      ),
    );
    await db.activityDao.insertActivityLog(
      ActivityLogCompanion.insert(
        activityId: 1,
        startedAt: start.millisecondsSinceEpoch,
      ),
    );
  });
  tearDown(() => db.close());

  test('manual finish and timer finish both enter the summary queue', () async {
    await EndActivityEntryUseCase(
      now: () => end,
      finishIfOpen: db.activityDao.finishActivityLogIfOpen,
      cancelIfUnchanged: db.activityDao.removeActivityLogIfOpen,
    )(
      ActivityLogSummaryData(
        id: 1,
        activityId: 1,
        activityName: 'Running',
        startedAt: start,
        endedAt: null,
        durationMinutes: null,
      ),
    );
    var entries = await db.activityDao.watchCompletedActivitySummaries().first;
    expect(entries.single.log.id, 1);
    expect(entries.single.log.summarizedAt, isNull);
    await db.activityDao.insertActivityLog(
      ActivityLogCompanion.insert(
        activityId: 1,
        startedAt: start.millisecondsSinceEpoch,
      ),
    );
    await AutoFinishActivityUseCase(
      now: () => end,
      finishIfOpen: db.activityDao.finishActivityLogIfOpen,
    )(activityLogId: 2, startsAt: start, durationMinutes: 30);
    entries = await db.activityDao.watchCompletedActivitySummaries().first;
    expect(entries.map((entry) => entry.log.id), containsAll([1, 2]));
  });

  test(
    'saving an empty summary or editing it keeps the entry off the dashboard',
    () async {
      await db.activityDao.finishActivityLogIfOpen(1, start, end);
      await db.activityDao.updateCompletedActivitySummary(
        id: 1,
        intensity: null,
        notes: null,
      );
      var log = await db.activityDao.getActivityLogById(1);
      expect(log.summarizedAt, isNotNull);
      await db.activityDao.updateCompletedActivitySummary(
        id: 1,
        intensity: 'high',
        notes: 'Tough',
      );
      log = await db.activityDao.getActivityLogById(1);
      expect(log.summarizedAt, isNotNull);
      expect(log.intensity, 'high');
      expect(log.notes, 'Tough');
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        completedActivitySummariesProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      expect(
        await container.read(completedActivitySummariesProvider.future),
        isEmpty,
      );

      expect(
        (await db.activityDao.watchCompletedActivitySummaries().first)
            .single
            .log
            .id,
        1,
      );
    },
  );

  test(
    'closing or skipping removes only the dashboard reminder, preserving history',
    () async {
      await db.activityDao.finishActivityLogIfOpen(1, start, end);
      await db.activityDao.updateCompletedActivitySummary(
        id: 1,
        intensity: 'light',
        notes: 'Easy',
      );
      expect(await db.activityDao.dismissActivitySummary(1), isTrue);
      expect(
        await db.activityDao.watchCompletedActivitySummaries().first,
        isEmpty,
      );
      final log = await db.activityDao.getActivityLogById(1);
      expect(log.notes, 'Easy');
      expect(log.summaryDismissedAt, isNotNull);
      await db.activityDao.updateCompletedActivitySummary(
        id: 1,
        intensity: 'moderate',
        notes: 'Edited in history',
      );
      expect(
        await db.activityDao.watchCompletedActivitySummaries().first,
        isEmpty,
      );
    },
  );
}
