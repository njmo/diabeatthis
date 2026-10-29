import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:diabeatthis/foreground/task/tasks/activity_monitor_task/helpers/activity_monitor_context_loader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../foreground/utils/fake_runtime_harness.dart';

void main() {
  late DatabaseImpl db;
  late ActivityScheduleService service;
  final now = DateTime(2026, 10, 29, 12);
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    service = ActivityScheduleService(db);
    await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Walk',
            percentagePre: 0,
            percentagePost: 0,
            durationMinutes: const Value(60),
          ),
        );
  });
  tearDown(() => db.close());

  test(
    'one-off manual duration overrides the activity default and reaches the monitor unchanged',
    () => withClock(Clock.fixed(now), () async {
      await service.planOnce(
        activityId: 1,
        start: now.add(const Duration(hours: 1)),
        durationMinutes: null,
      );
      final occurrence = (await db.select(db.activityOccurrence).get()).single;
      expect(occurrence.durationMinutes, isNull);
      expect(occurrence.status, 'planned');
      final logId = occurrence.activityLogId!;
      expect(
        await db.activityDao.getEffectiveDurationForLog(logId, 60),
        isNull,
      );
      final harness = FakeRuntimeHarness(
        container: ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        ),
      );
      addTearDown(harness.dispose);
      final context = await loadActivityMonitorContext(
        harness.runtimeContext,
        logId,
      );
      expect(context!.durationMinutes, isNull);
    }),
  );

  test(
    'recurring manual sessions remain manual when confirmed and moved',
    () => withClock(Clock.fixed(now), () async {
      await service.save(
        activityId: 1,
        weekdays: {now.weekday},
        startMinute: 18 * 60,
        durationMinutes: null,
        mode: 'before',
        validFrom: DateTime(now.year, now.month, now.day),
      );
      final rule = (await db.select(db.activitySchedule).get()).single;
      expect(rule.durationMinutes, isNull);
      final occurrence = (await db.select(db.activityOccurrence).get()).first;
      expect(occurrence.durationMinutes, isNull);
      await service.confirm(occurrence.id);
      await service.move(occurrence.id, now.add(const Duration(hours: 7)));
      final planned = (await db.select(db.activityOccurrence).get())
          .where((row) => row.status == 'planned')
          .single;
      expect(planned.durationMinutes, isNull);
      expect(
        await db.activityDao.getEffectiveDurationForLog(
          planned.activityLogId!,
          60,
        ),
        isNull,
      );
    }),
  );

  test(
    'zero and negative durations remain invalid while an absent duration is supported',
    () => withClock(Clock.fixed(now), () async {
      for (final duration in [0, -1]) {
        await expectLater(
          service.planOnce(
            activityId: 1,
            start: now.add(const Duration(hours: 1)),
            durationMinutes: duration,
          ),
          throwsArgumentError,
        );
        await expectLater(
          service.save(
            activityId: 1,
            weekdays: {now.weekday},
            startMinute: 18 * 60,
            durationMinutes: duration,
            mode: 'before',
            validFrom: now,
          ),
          throwsArgumentError,
        );
      }
      expect(await db.select(db.activityOccurrence).get(), isEmpty);
    }),
  );
}
