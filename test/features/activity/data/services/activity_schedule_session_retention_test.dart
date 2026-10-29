import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/mappers/activity_log_summary_data_mapper.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ActivityScheduleService service;
  late DateTime now;
  final startsAt = DateTime(2026, 10, 29, 18);

  setUp(() async {
    now = DateTime(2026, 10, 29, 17);
    db = DatabaseImpl(NativeDatabase.memory());
    service = ActivityScheduleService(db);
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
  tearDown(() => db.close());

  Future<({int ruleId, List<ActivityOccurrenceData> occurrences})> plan(
    int? duration,
  ) async {
    await service.save(
      activityId: 1,
      weekdays: {now.weekday},
      startMinute: 18 * 60,
      durationMinutes: duration,
      mode: 'before',
      validFrom: DateTime(now.year, now.month, now.day),
    );
    final rule = (await db.select(db.activitySchedule).get()).single;
    final occurrences =
        await (db.select(db.activityOccurrence)
              ..where((row) => row.scheduleId.equals(rule.id))
              ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]))
            .get();
    return (ruleId: rule.id, occurrences: occurrences);
  }

  for (final duration in <int?>[null, 45]) {
    for (final completed in [false, true]) {
      test(
        'removing recurrence preserves duration $duration for ${completed ? 'completed' : 'ongoing'} session',
        () => withClock(Clock(() => now), () async {
          final planned = await plan(duration);
          final occurrence = planned.occurrences.first;
          final logId = (await service.confirm(occurrence.id))!;
          now = startsAt.add(const Duration(minutes: 10));
          if (completed) {
            await db.activityDao.finishActivityLogIfOpen(logId, startsAt, now);
          }
          await service.removeSchedule(planned.ruleId);
          final retained =
              (await db.select(db.activityOccurrence).get()).single;
          expect(retained.id, occurrence.id);
          expect(retained.scheduleId, isNull);
          expect(retained.activityLogId, logId);
          expect(retained.durationMinutes, duration);
          expect(
            await db.activityDao.getEffectiveDurationForLog(logId, 60),
            duration,
          );
          final views = await db.activityDao.watchActivityLogViews().first;
          expect(views.single.toSummaryData().durationMinutes, duration);
          expect(
            (await db.activityDao.getActivityLogById(logId)).endedAt,
            completed ? now.millisecondsSinceEpoch : null,
          );
          await service.refresh();
          expect(await db.select(db.activitySchedule).get(), isEmpty);
          expect(await db.select(db.activityOccurrence).get(), hasLength(1));
          expect(
            await db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        }),
      );
    }
  }

  test(
    'removal cancels future reservations while retaining the ongoing session',
    () => withClock(Clock(() => now), () async {
      final planned = await plan(null);
      final ongoingId = (await service.confirm(planned.occurrences.first.id))!;
      final futureId = (await service.confirm(planned.occurrences[1].id))!;
      now = startsAt.add(const Duration(minutes: 10));
      await service.removeSchedule(planned.ruleId);
      expect((await db.select(db.activityLog).get()).map((row) => row.id), [
        ongoingId,
      ]);
      expect(await db.activityDao.getActivityLogByIdOrNull(futureId), isNull);
      final retained = (await db.select(db.activityOccurrence).get()).single;
      expect(retained.activityLogId, ongoingId);
      expect(retained.durationMinutes, isNull);
      await service.refresh();
      expect(await db.select(db.activityOccurrence).get(), hasLength(1));
    }),
  );

  test(
    'actual started log is retained when its planned occurrence is still future',
    () => withClock(Clock(() => now), () async {
      final planned = await plan(45);
      final occurrence = planned.occurrences.first;
      final logId = (await service.confirm(occurrence.id))!;
      await (db.update(
        db.activityLog,
      )..where((row) => row.id.equals(logId))).write(
        ActivityLogCompanion(
          startedAt: Value(
            now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
          ),
        ),
      );
      await service.removeSchedule(planned.ruleId);
      final retained = (await db.select(db.activityOccurrence).get()).single;
      expect(retained.id, occurrence.id);
      expect(retained.scheduleId, isNull);
      expect(retained.activityLogId, logId);
      expect(await db.activityDao.getEffectiveDurationForLog(logId, 60), 45);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    }),
  );
}
