import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/mappers/activity_log_summary_data_mapper.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  final now = DateTime(2026, 10, 29, 12);
  final start = DateTime(2026, 10, 29, 17);

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Jujitsu',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ActivityLogSummaryData?> pendingActivity() {
    final subscription = container.listen(
      getPendingActivityProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    return container.read(getPendingActivityProvider.future);
  }

  for (final duration in <int?>[45, null]) {
    test(
      'dashboard and related activity use the session duration $duration instead of the definition',
      () => withClock(Clock.fixed(now), () async {
        await ActivityScheduleService(
          db,
        ).planOnce(activityId: 1, start: start, durationMinutes: duration);
        final occurrence =
            (await db.select(db.activityOccurrence).get()).single;

        final pending = await pendingActivity();
        expect(pending!.durationMinutes, duration);
        expect(
          (await db.activityDao.getActiveActivityLogView())!
              .toSummaryData()
              .durationMinutes,
          duration,
        );
        expect(
          await db.activityDao.getEffectiveDurationForLog(
            occurrence.activityLogId!,
            60,
          ),
          duration,
        );

        final history = await db.activityDao.watchActivityLogViews().first;
        expect(history.single.toSummaryData().durationMinutes, duration);
        final overlapping = await db.activityDao.getActivityLogsOverlapping(
          start,
          start.add(const Duration(hours: 1)),
        );
        expect(overlapping.single.toSummaryData().durationMinutes, duration);
      }),
    );
  }

  test(
    'a log without a scheduled occurrence keeps the activity default',
    () async {
      final logId = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: 1,
              startedAt: start.millisecondsSinceEpoch,
            ),
          );

      final pending = await pendingActivity();
      expect(pending!.durationMinutes, 60);
      expect(await db.activityDao.getEffectiveDurationForLog(logId, 60), 60);
    },
  );

  test(
    'dashboard refreshes when only the occurrence duration becomes unspecified',
    () => withClock(Clock.fixed(now), () async {
      await ActivityScheduleService(
        db,
      ).planOnce(activityId: 1, start: start, durationMinutes: 45);
      final occurrence = (await db.select(db.activityOccurrence).get()).single;
      final updated = Completer<ActivityLogSummaryData>();
      final subscription = container.listen(getPendingActivityProvider, (
        _,
        next,
      ) {
        final summary = next.asData?.value;
        if (summary != null &&
            summary.durationMinutes == null &&
            !updated.isCompleted) {
          updated.complete(summary);
        }
      });
      addTearDown(subscription.close);
      expect(
        (await container.read(
          getPendingActivityProvider.future,
        ))!.durationMinutes,
        45,
      );

      await (db.update(
        db.activityOccurrence,
      )..where((row) => row.id.equals(occurrence.id))).write(
        const ActivityOccurrenceCompanion(durationMinutes: Value(null)),
      );

      final summary = await updated.future.timeout(const Duration(seconds: 5));
      expect(summary.id, occurrence.activityLogId);
      expect(summary.durationMinutes, isNull);
      expect((await db.activityDao.getActivityById(1)).durationMinutes, 60);
    }),
  );
}
