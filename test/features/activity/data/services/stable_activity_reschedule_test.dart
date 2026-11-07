import 'package:clock/clock.dart';
import 'package:diabeatthis/common/events/data/notification/activity_schedule_response_event.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:diabeatthis/core/notifications/domain/events/activity_schedule_notification.dart';
import 'package:diabeatthis/features/activity/data/services/activity_schedule_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

final stableNow = DateTime(2026, 11, 7, 12);
final stableStart = DateTime(2026, 11, 11, 17);
Future<ActivityOccurrenceData> stableRule(
  DatabaseImpl db,
  ActivityScheduleService service, {
  bool confirmed = false,
  int? duration = 43,
}) async {
  await db.customStatement(
    "INSERT INTO activity(name,percentage_pre,percentage_post,duration_minutes) VALUES('Training',20,30,60)",
  );
  await service.save(
    activityId: 1,
    weekdays: {stableStart.weekday},
    startMinute: 17 * 60,
    durationMinutes: duration,
    mode: 'before',
    validFrom: stableNow,
  );
  final row = await db.select(db.activityOccurrence).getSingle();
  if (confirmed) await service.confirm(row.id);
  return (await db.select(db.activityOccurrence).getSingle());
}

void main() {
  for (final confirmed in [false, true]) {
    for (final duration in <int?>[43, null]) {
      test(
        'same session moves without a skipped duplicate: confirmed=$confirmed duration=$duration',
        () => withClock(Clock.fixed(stableNow), () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          addTearDown(db.close);
          final cancelled = <int>[];
          final service = ActivityScheduleService(
            db,
            cancelConfirmation: (id) async {
              cancelled.add(id);
            },
          );
          final original = await stableRule(
            db,
            service,
            confirmed: confirmed,
            duration: duration,
          );
          final next = stableStart.add(const Duration(hours: 1));
          await service.move(original.id, next);
          await service.refresh();
          final row = await db.select(db.activityOccurrence).getSingle();
          expect(row.id, original.id);
          expect(row.startedAt, next.millisecondsSinceEpoch);
          expect(row.durationMinutes, duration);
          expect(row.status, confirmed ? 'planned' : 'pending');
          expect(row.askedAt, isNull);
          expect(row.targetRequestedAt, isNull);
          expect(
            (await db.select(db.activityScheduleException).getSingle())
                .startedAt,
            original.startedAt,
          );
          expect(
            (await db.select(db.activityOccurrenceReschedule).getSingle())
                .originalStartedAt,
            original.startedAt,
          );
          expect(cancelled, [original.id]);
          final logs = await db.select(db.activityLog).get();
          expect(logs, hasLength(confirmed ? 1 : 0));
          if (confirmed) {
            expect(logs.single.startedAt, next.millisecondsSinceEpoch);
            expect(logs.single.id, isNot(original.activityLogId));
          }
          final marker = (await FamilyMirrorOutbox(db).pending())
              .where((r) => r.kind == 'activityOccurrenceReschedules')
              .single;
          expect(marker.id, '${original.id}');
          expect(marker.payload!['original_started_at'], original.startedAt);
        }),
      );
    }
  }
  test(
    'A to B to A rejects stale notification generations and preserves explicit skip',
    () => withClock(Clock.fixed(stableNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final cancelled = <int>[];
      final service = ActivityScheduleService(
        db,
        cancelConfirmation: (id) async {
          cancelled.add(id);
        },
      );
      final row = await stableRule(db, service);
      await service.move(row.id, stableStart.add(const Duration(hours: 1)));
      await service.move(row.id, stableStart);
      await service.refresh();
      expect(
        (await db.select(db.activityOccurrenceReschedule).getSingle())
            .notificationRevision,
        2,
      );
      expect(
        await service.confirm(
          row.id,
          fromNotification: true,
          expectedStartedAt: row.startedAt,
          expectedRevision: 0,
        ),
        isNull,
      );
      expect(await service.confirm(row.id, fromNotification: true), isNull);
      await service.skip(
        row.id,
        fromNotification: true,
        expectedStartedAt: row.startedAt,
        expectedRevision: 0,
      );
      expect(cancelled, hasLength(2));
      expect(
        (await db.select(db.activityOccurrence).getSingle()).status,
        'pending',
      );
      await service.confirm(
        row.id,
        fromNotification: true,
        expectedStartedAt: row.startedAt,
        expectedRevision: 2,
      );
      await service.skip(
        row.id,
        fromNotification: true,
        expectedStartedAt: row.startedAt,
        expectedRevision: 0,
      );
      expect(
        (await db.select(db.activityOccurrence).getSingle()).status,
        'planned',
      );
      await service.skip(
        row.id,
        fromNotification: true,
        expectedStartedAt: row.startedAt,
        expectedRevision: 2,
      );
      await service.refresh();
      expect(
        (await db.select(db.activityOccurrence).getSingle()).status,
        'skipped',
      );
      expect(cancelled, hasLength(3));
    }),
  );
  test(
    'stale child forms cannot move or delete a newer reservation',
    () => withClock(Clock.fixed(stableNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final service = ActivityScheduleService(db);
      final row = await stableRule(db, service);
      final next = stableStart.add(const Duration(hours: 1));
      await service.move(row.id, next);
      await expectLater(
        service.move(
          row.id,
          stableStart.add(const Duration(hours: 2)),
          expectedStartedAt: row.startedAt,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      await expectLater(
        service.removeOccurrence(
          row.id,
          expectedStartedAt: row.startedAt,
          expectedRevision: 0,
        ),
        throwsStateError,
      );
      expect(
        (await db.select(db.activityOccurrence).getSingle()).startedAt,
        next.millisecondsSinceEpoch,
      );
    }),
  );
  test(
    'occupied destination rolls back the session, reservation, exceptions and mirror',
    () => withClock(Clock.fixed(stableNow), () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final cancelled = <int>[];
      final service = ActivityScheduleService(
        db,
        cancelConfirmation: (id) async {
          cancelled.add(id);
        },
      );
      final row = await stableRule(db, service, confirmed: true);
      final target = stableStart
          .add(const Duration(hours: 1))
          .millisecondsSinceEpoch;
      await db
          .into(db.activityOccurrence)
          .insert(
            ActivityOccurrenceCompanion.insert(
              activityId: 1,
              scheduleId: Value(row.scheduleId),
              startedAt: target,
              actionAt: target,
              confirmationMode: 'before',
            ),
          );
      final before = await db
          .customSelect(
            'SELECT kind,entity_id,revision FROM family_sync_outbox ORDER BY kind,entity_id',
          )
          .get();
      await expectLater(
        service.move(row.id, DateTime.fromMillisecondsSinceEpoch(target)),
        throwsA(isA<Exception>()),
      );
      expect(
        (await (db.select(
          db.activityOccurrence,
        )..where((r) => r.id.equals(row.id))).getSingle()).startedAt,
        row.startedAt,
      );
      expect(
        (await db.select(db.activityLog).getSingle()).id,
        row.activityLogId,
      );
      expect(await db.select(db.activityScheduleException).get(), isEmpty);
      expect(await db.select(db.activityOccurrenceReschedule).get(), isEmpty);
      expect(
        (await db
                .customSelect(
                  'SELECT kind,entity_id,revision FROM family_sync_outbox ORDER BY kind,entity_id',
                )
                .get())
            .map((r) => r.data)
            .toList(),
        before.map((r) => r.data).toList(),
      );
      expect(cancelled, isEmpty);
    }),
  );
  test('notification payload round trips the exact occurrence version', () {
    final notification = ActivityScheduleNotificationEvent(
      occurrenceId: 7,
      activityName: 'Training',
      startsAt: stableStart,
      revision: 2,
    );
    final data = notification.toPayload()['action_data'] as Map;
    final event = ActivityScheduleResponseEvent.fromJson({
      ...Map<String, dynamic>.from(data),
      'action': 'agree',
    });
    expect(event.expectedStartedAt, stableStart.millisecondsSinceEpoch);
    expect(event.expectedRevision, 2);
    expect(
      ActivityScheduleNotificationEvent.fromPayload(
        notification.toJson(),
      ).revision,
      2,
    );
  });
}
