import 'package:clock/clock.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_log_draft.dart';
import 'package:diabeatthis/features/activity/data/providers/activity_provider.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:diabeatthis/features/activity/domain/activity_schedule_time.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ActivityScheduleService service;
  final now = DateTime(2026, 10, 28, 6);

  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    service = ActivityScheduleService(db);
    await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'PE',
            percentagePre: 0,
            percentagePost: 0,
          ),
        );
  });
  tearDown(() => db.close());

  Future<void> rule({String mode = 'before'}) => service.save(
    activityId: 1,
    weekdays: {1, 2, 3},
    startMinute: 8 * 60,
    durationMinutes: 45,
    mode: mode,
    validFrom: DateTime(2026, 10, 28),
  );

  test(
    'refresh builds calendar occurrences without duplicates',
    () => withClock(Clock.fixed(now), () async {
      await rule();
      final first = await db.select(db.activityOccurrence).get();
      await service.refresh();
      final second = await db.select(db.activityOccurrence).get();
      expect(second.length, first.length);
      expect(
        second.first.startedAt,
        DateTime(2026, 10, 28, 8).millisecondsSinceEpoch,
      );
      expect(
        second.first.actionAt,
        DateTime(2026, 10, 28, 6, 30).millisecondsSinceEpoch,
      );
      expect(
        second.map(
          (r) => DateTime.fromMillisecondsSinceEpoch(r.startedAt).weekday,
        ),
        everyElement(isIn([1, 2, 3])),
      );
    }),
  );

  test(
    'previous-day confirmation has an evening deadline',
    () => withClock(Clock.fixed(now), () async {
      await rule(mode: 'previous_day');
      final row = (await db.select(db.activityOccurrence).get()).first;
      expect(row.actionAt, DateTime(2026, 10, 27, 19).millisecondsSinceEpoch);
    }),
  );

  test(
    'confirm is idempotent and supports multiple reserved sessions',
    () => withClock(Clock.fixed(now), () async {
      await rule();
      final rows = await db.select(db.activityOccurrence).get();
      await service.confirm(rows.first.id);
      await service.confirm(rows.first.id);
      await service.confirm(rows[1].id);
      final logs = await db.select(db.activityLog).get();
      expect(logs.length, 2);
      expect((await db.activityDao.getNearestActivityLog())?.id, logs.first.id);
    }),
  );

  test(
    'skip cancels only one occurrence and refresh preserves the exception',
    () => withClock(Clock.fixed(now), () async {
      await rule();
      final rows = await db.select(db.activityOccurrence).get();
      await service.confirm(rows.first.id);
      await service.skip(rows.first.id);
      await service.refresh();
      expect(await db.select(db.activityLog).get(), isEmpty);
      final updated = await db.select(db.activityOccurrence).get();
      expect(updated.first.status, 'skipped');
      expect(updated[1].status, 'pending');
      expect(updated.length, rows.length);
    }),
  );

  test(
    'reschedule preserves the original exception across refresh',
    () => withClock(Clock.fixed(now), () async {
      await rule();
      final row = (await db.select(db.activityOccurrence).get()).first;
      await service.confirm(row.id);
      await service.move(row.id, DateTime(2026, 10, 28, 9));
      await service.refresh();
      final rows = await db.select(db.activityOccurrence).get();
      expect(rows.singleWhere((r) => r.id == row.id).status, 'skipped');
      expect(
        rows
            .where(
              (r) =>
                  r.startedAt ==
                  DateTime(2026, 10, 28, 9).millisecondsSinceEpoch,
            )
            .length,
        1,
      );
      final logs = await db.select(db.activityLog).get();
      expect(logs, hasLength(1));
      expect(
        logs.single.startedAt,
        DateTime(2026, 10, 28, 9).millisecondsSinceEpoch,
      );
    }),
  );

  test(
    'pausing a rule cancels future reservations and leaves history',
    () => withClock(Clock.fixed(now), () async {
      await rule();
      final row = (await db.select(db.activityOccurrence).get()).first;
      await service.confirm(row.id);
      final schedule = (await db.select(db.activitySchedule).get()).single;
      await service.setEnabled(schedule, false);
      await service.refresh();
      expect(await db.select(db.activityOccurrence).get(), isEmpty);
      expect(await db.select(db.activityLog).get(), isEmpty);
    }),
  );

  test(
    'unanswered expired sessions are missed and cannot be confirmed late',
    () async {
      await withClock(Clock.fixed(now), () => rule());
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 9)), () async {
        await service.refresh();
        final row = (await db.select(db.activityOccurrence).get()).first;
        expect(row.status, 'missed');
        expect(await service.confirm(row.id), isNull);
        expect(await db.select(db.activityLog).get(), isEmpty);
      });
    },
  );

  test(
    'historical insertion stores a closed interval without opening a session',
    () => withClock(Clock.fixed(now), () async {
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final log = await container.read(
        insertActivityLogProvider(
          ActivityLogDraft(
            activity: const ActivityDraft.existing(
              id: 1,
              name: 'PE',
              percentagePre: 0,
              percentagePost: 0,
              durationMinutes: null,
            ),
            startedAt: now.subtract(const Duration(hours: 2)),
            endedAt: now.subtract(const Duration(hours: 1)),
          ),
        ).future,
      );
      expect(log.endedAt, now.subtract(const Duration(hours: 1)));
      expect(log.endedAt!.difference(log.startedAt), const Duration(hours: 1));
      expect(await db.activityDao.getNearestActivityLog(), isNull);
    }),
  );

  test('calendar recurrence uses wall time across a month boundary', () {
    final start = activityScheduleStart(DateTime(2026, 11, 1), 7 * 60);
    expect(start, DateTime(2026, 11, 1, 7));
    expect(
      activityScheduleActionAt(start, 'previous_day', 19 * 60),
      DateTime(2026, 10, 31, 19),
    );
  });
}
