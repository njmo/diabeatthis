import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ActivityScheduleService service;
  final now = DateTime(2026, 10, 28, 12);
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    service = ActivityScheduleService(db);
    await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Jujitsu',
            percentagePre: 10,
            percentagePost: 20,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> saveRule(int hour, {int? id}) => service.save(
    id: id,
    activityId: 1,
    weekdays: {3},
    startMinute: hour * 60,
    durationMinutes: 60,
    mode: 'before',
    validFrom: DateTime(2026, 10, 28),
  );

  test(
    'incorrect past occurrence can be removed after correcting the rule',
    () => withClock(Clock.fixed(now), () async {
      await saveRule(8);
      final rule = (await db.select(db.activitySchedule).get()).single;
      final incorrect = (await db.select(db.activityOccurrence).get()).first;
      expect(incorrect.status, 'missed');
      await saveRule(17, id: rule.id);
      await service.removeOccurrence(incorrect.id);
      await service.refresh();
      await service.refresh();
      final rows = await db.select(db.activityOccurrence).get();
      expect(rows.singleWhere((r) => r.id == incorrect.id).status, 'deleted');
      expect(
        rows.where(
          (r) =>
              r.status != 'deleted' &&
              r.startedAt == DateTime(2026, 10, 28, 8).millisecondsSinceEpoch,
        ),
        isEmpty,
      );
      expect(
        rows.where(
          (r) =>
              r.startedAt == DateTime(2026, 10, 28, 17).millisecondsSinceEpoch,
        ),
        hasLength(1),
      );
      expect(await db.select(db.activityLog).get(), isEmpty);
    }),
  );

  test(
    'deleting a reservation cancels its log and survives a paused cycle',
    () => withClock(Clock.fixed(now), () async {
      await saveRule(17);
      final rule = (await db.select(db.activitySchedule).get()).single;
      final row = (await db.select(db.activityOccurrence).get()).first;
      await service.confirm(row.id);
      await service.removeOccurrence(row.id);
      await service.setEnabled(rule, false);
      await service.setEnabled(rule, true);
      await service.refresh();
      expect(await db.select(db.activityLog).get(), isEmpty);
      final rows = await db.select(db.activityOccurrence).get();
      expect(
        rows.singleWhere((r) => r.startedAt == row.startedAt).status,
        'deleted',
      );
      expect(await service.confirm(row.id), isNull);
    }),
  );

  test(
    'removing a cycle keeps completed activity history and cancels future logs',
    () => withClock(Clock.fixed(now), () async {
      await saveRule(17);
      final rule = (await db.select(db.activitySchedule).get()).single;
      final row = (await db.select(db.activityOccurrence).get()).first;
      await service.confirm(row.id);
      final completed = await db.activityDao.insertActivityLog(
        ActivityLogCompanion.insert(
          activityId: 1,
          startedAt: now
              .subtract(const Duration(hours: 2))
              .millisecondsSinceEpoch,
          endedAt: Value(
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
          ),
        ),
      );
      await service.removeSchedule(rule.id);
      expect(await db.select(db.activitySchedule).get(), isEmpty);
      expect(await db.select(db.activityOccurrence).get(), isEmpty);
      final history = await db.select(db.activityLog).get();
      expect(history, hasLength(1));
      expect(history.single.id, completed.id);
    }),
  );

  test(
    'an occurrence with an already started log cannot be deleted from upcoming',
    () async {
      late int occurrenceId;
      await withClock(Clock.fixed(now), () async {
        await saveRule(17);
        occurrenceId = (await db.select(db.activityOccurrence).get()).first.id;
        await service.confirm(occurrenceId);
      });
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 18)), () async {
        await expectLater(
          service.removeOccurrence(occurrenceId),
          throwsStateError,
        );
        expect(await db.select(db.activityLog).get(), hasLength(1));
      });
    },
  );
}
