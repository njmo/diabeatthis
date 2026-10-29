import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../domain/activity_schedule_time.dart';

final activityScheduleServiceProvider = Provider<ActivityScheduleService>(
  (ref) => ActivityScheduleService(ref.watch(databaseProvider)),
);

final activitySchedulesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.activitySchedule,
  )..orderBy([(row) => OrderingTerm.asc(row.startMinute)])).watch();
});

final activityOccurrencesProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.activityOccurrence,
  )..orderBy([(row) => OrderingTerm.asc(row.startedAt)])).watch();
});

class ActivityScheduleService {
  const ActivityScheduleService(this.db);
  final DatabaseImpl db;

  Future<void> save({
    int? id,
    required int activityId,
    required Set<int> weekdays,
    required int startMinute,
    required int? durationMinutes,
    required String mode,
    required DateTime validFrom,
    DateTime? validUntil,
    int previousDayMinute = 19 * 60,
  }) async {
    if (weekdays.isEmpty ||
        weekdays.any((day) => day < 1 || day > 7) ||
        (durationMinutes != null && durationMinutes <= 0) ||
        startMinute < 0 ||
        startMinute >= 1440 ||
        previousDayMinute < 0 ||
        previousDayMinute >= 1440 ||
        !['before', 'previous_day', 'automatic'].contains(mode) ||
        (validUntil != null && validUntil.isBefore(validFrom))) {
      throw ArgumentError('Invalid activity schedule');
    }
    await db.transaction(() async {
      if (id != null) await clearFuture(id);
      final days = weekdays.toList()..sort();
      final row = ActivityScheduleCompanion.insert(
        activityId: activityId,
        weekdays: days.join(','),
        startMinute: startMinute,
        durationMinutes: Value(durationMinutes),
        confirmationMode: mode,
        previousDayMinute: Value(previousDayMinute),
        validFrom: validFrom.millisecondsSinceEpoch,
        validUntil: Value(validUntil?.millisecondsSinceEpoch),
      );
      if (id == null) {
        await db.into(db.activitySchedule).insert(row);
      } else {
        await (db.update(
          db.activitySchedule,
        )..where((r) => r.id.equals(id))).write(row);
      }
      await refresh();
    });
  }

  Future<void> setEnabled(ActivityScheduleData rule, bool enabled) async {
    await db.transaction(() async {
      if (!enabled) await clearFuture(rule.id);
      await (db.update(db.activitySchedule)..where((r) => r.id.equals(rule.id)))
          .write(ActivityScheduleCompanion(enabled: Value(enabled)));
      await refresh();
    });
  }

  Future<void> clearFuture(int scheduleId) async {
    final rows =
        await (db.select(db.activityOccurrence)..where(
              (r) =>
                  r.scheduleId.equals(scheduleId) &
                  r.startedAt.isBiggerThanValue(
                    clock.now().millisecondsSinceEpoch,
                  ),
            ))
            .get();
    for (final row in rows) {
      if (row.status == 'deleted') continue;
      await cancelLog(row);
      await (db.delete(
        db.activityOccurrence,
      )..where((r) => r.id.equals(row.id))).go();
    }
  }

  Future<void> cancelLog(ActivityOccurrenceData row) async {
    if (row.activityLogId != null &&
        row.startedAt > clock.now().millisecondsSinceEpoch) {
      await (db.delete(
            db.activityLog,
          )..where((r) => r.id.equals(row.activityLogId!) & r.endedAt.isNull()))
          .go();
    }
  }

  Future<void> refresh() async {
    final now = clock.now();
    final rules = await (db.select(
      db.activitySchedule,
    )..where((r) => r.enabled.equals(true))).get();
    final existing = await db.select(db.activityOccurrence).get();
    final keys = {
      for (final row in existing) '${row.scheduleId}:${row.startedAt}',
    };
    for (final rule in rules) {
      final weekdays = rule.weekdays.split(',').map(int.parse).toSet();
      for (var offset = 0; offset <= 8; offset++) {
        final day = DateTime(now.year, now.month, now.day + offset);
        final start = activityScheduleStart(day, rule.startMinute);
        if (!weekdays.contains(day.weekday) ||
            start.millisecondsSinceEpoch < rule.validFrom ||
            (rule.validUntil != null &&
                day.millisecondsSinceEpoch > rule.validUntil!)) {
          continue;
        }
        if (!keys.add('${rule.id}:${start.millisecondsSinceEpoch}')) {
          continue;
        }
        await db
            .into(db.activityOccurrence)
            .insert(
              ActivityOccurrenceCompanion.insert(
                scheduleId: Value(rule.id),
                activityId: rule.activityId,
                startedAt: start.millisecondsSinceEpoch,
                durationMinutes: Value(rule.durationMinutes),
                actionAt: activityScheduleActionAt(
                  start,
                  rule.confirmationMode,
                  rule.previousDayMinute,
                ).millisecondsSinceEpoch,
                confirmationMode: rule.confirmationMode,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    }
    for (final row in existing.where((row) => row.status == 'planned')) {
      final log = row.activityLogId == null
          ? null
          : await db.activityDao.getActivityLogByIdOrNull(row.activityLogId!);
      final status = log == null
          ? 'skipped'
          : log.endedAt != null
          ? 'recorded'
          : null;
      if (status != null) {
        await (db.update(db.activityOccurrence)
              ..where((r) => r.id.equals(row.id) & r.status.equals('planned')))
            .write(ActivityOccurrenceCompanion(status: Value(status)));
      }
    }
    final expired =
        await (db.select(db.activityOccurrence)..where(
              (row) =>
                  row.status.equals('pending') &
                  row.startedAt.isSmallerOrEqualValue(
                    now.millisecondsSinceEpoch,
                  ),
            ))
            .get();
    final expiredIds = expired.map((row) => row.id).toList();
    if (expiredIds.isNotEmpty) {
      await (db.update(db.activityOccurrence)
            ..where((r) => r.id.isIn(expiredIds) & r.status.equals('pending')))
          .write(const ActivityOccurrenceCompanion(status: Value('missed')));
    }
  }

  /// A transaction makes UI taps and notification responses idempotent.
  Future<int?> confirm(int occurrenceId) => db.transaction(() async {
    final row = await (db.select(
      db.activityOccurrence,
    )..where((r) => r.id.equals(occurrenceId))).getSingleOrNull();
    if (row == null ||
        row.status != 'pending' ||
        row.startedAt <= clock.now().millisecondsSinceEpoch) {
      return null;
    }
    final log = await db.activityDao.insertActivityLog(
      ActivityLogCompanion.insert(
        activityId: row.activityId,
        startedAt: row.startedAt,
      ),
    );
    await (db.update(
      db.activityOccurrence,
    )..where((r) => r.id.equals(row.id))).write(
      ActivityOccurrenceCompanion(
        status: const Value('planned'),
        activityLogId: Value(log.id),
      ),
    );
    return log.id;
  });

  Future<void> skip(int id) => db.transaction(() async {
    final row = await (db.select(
      db.activityOccurrence,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null ||
        row.status == 'deleted' ||
        row.startedAt <= clock.now().millisecondsSinceEpoch) {
      return;
    }
    await cancelLog(row);
    await (db.update(db.activityOccurrence)..where((r) => r.id.equals(id)))
        .write(const ActivityOccurrenceCompanion(status: Value('skipped')));
  });

  /// Keep the occurrence key as a tombstone so recurring refresh cannot recreate it.
  /// Executed sessions are managed through activity history, never deleted here.
  Future<void> removeOccurrence(int id) => db.transaction(() async {
    final row = await (db.select(
      db.activityOccurrence,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null || row.status == 'deleted') return;
    final log = row.activityLogId == null
        ? null
        : await db.activityDao.getActivityLogByIdOrNull(row.activityLogId!);
    if (row.status == 'recorded' ||
        (log != null && log.startedAt <= clock.now().millisecondsSinceEpoch)) {
      throw StateError('An executed activity must be managed in history');
    }
    await cancelLog(row);
    await (db.update(
      db.activityOccurrence,
    )..where((r) => r.id.equals(id))).write(
      const ActivityOccurrenceCompanion(
        status: Value('deleted'),
        activityLogId: Value(null),
      ),
    );
  });

  Future<void> removeSchedule(int id) => db.transaction(() async {
    final sessions =
        await (db.select(db.activityOccurrence).join([
                innerJoin(
                  db.activityLog,
                  db.activityLog.id.equalsExp(
                    db.activityOccurrence.activityLogId,
                  ),
                ),
              ])
              ..where(db.activityOccurrence.scheduleId.equals(id))
              ..where(
                db.activityLog.startedAt.isSmallerOrEqualValue(
                      clock.now().millisecondsSinceEpoch,
                    ) |
                    db.activityLog.endedAt.isNotNull(),
              ))
            .get();
    final retainedIds = sessions
        .map((row) => row.readTable(db.activityOccurrence).id)
        .toList();
    if (retainedIds.isNotEmpty) {
      // Session duration is historical data even after its recurrence is removed.
      await (db.update(db.activityOccurrence)
            ..where((row) => row.id.isIn(retainedIds)))
          .write(const ActivityOccurrenceCompanion(scheduleId: Value(null)));
    }
    await clearFuture(id);
    await (db.delete(db.activitySchedule)..where((r) => r.id.equals(id))).go();
  });

  Future<void> planOnce({
    required int activityId,
    required DateTime start,
    required int? durationMinutes,
  }) async {
    if (!start.isAfter(clock.now()) ||
        (durationMinutes != null && durationMinutes <= 0)) {
      throw ArgumentError('Invalid planned activity');
    }
    await db.transaction(() async {
      final id = await db
          .into(db.activityOccurrence)
          .insert(
            ActivityOccurrenceCompanion.insert(
              activityId: activityId,
              startedAt: start.millisecondsSinceEpoch,
              durationMinutes: Value(durationMinutes),
              confirmationMode: 'automatic',
              actionAt: start
                  .subtract(activityPreparationLeadTime)
                  .millisecondsSinceEpoch,
            ),
          );
      await confirm(id);
    });
  }

  Future<void> move(int id, DateTime start) => db.transaction(() async {
    final row = await (db.select(
      db.activityOccurrence,
    )..where((r) => r.id.equals(id))).getSingle();
    if (!['pending', 'planned'].contains(row.status) ||
        start.isBefore(clock.now()) ||
        row.startedAt <= clock.now().millisecondsSinceEpoch) {
      throw ArgumentError('Only future occurrences can be moved');
    }
    if (start.millisecondsSinceEpoch == row.startedAt) return;
    final rule = row.scheduleId == null
        ? null
        : await (db.select(
            db.activitySchedule,
          )..where((r) => r.id.equals(row.scheduleId!))).getSingleOrNull();
    final alreadyPlanned = row.status == 'planned';
    await cancelLog(row);
    // Keep the original occurrence as an exception so refresh cannot recreate it.
    await (db.update(db.activityOccurrence)..where((r) => r.id.equals(id)))
        .write(const ActivityOccurrenceCompanion(status: Value('skipped')));
    final newId = await db
        .into(db.activityOccurrence)
        .insert(
          ActivityOccurrenceCompanion.insert(
            scheduleId: Value(row.scheduleId),
            activityId: row.activityId,
            startedAt: start.millisecondsSinceEpoch,
            durationMinutes: Value(row.durationMinutes),
            confirmationMode: row.confirmationMode,
            actionAt: activityScheduleActionAt(
              start,
              row.confirmationMode,
              rule?.previousDayMinute ?? 19 * 60,
            ).millisecondsSinceEpoch,
          ),
        );
    if (alreadyPlanned) await confirm(newId);
  });
}
