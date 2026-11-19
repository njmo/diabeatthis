import 'package:drift/drift.dart';

import '../../../core/drift/database_impl.dart';

const scheduledMealDecisionRecoveryWindow = Duration(minutes: 30);

typedef ScheduledMealDecision = ({String uid, String requestId, bool handled});

Future<void> installScheduledMealDecisionJournal(DatabaseImpl db) =>
    db.customStatement('''
      CREATE TABLE IF NOT EXISTS scheduled_meal_decision (
        meal_id INTEGER NOT NULL,
        planned_at INTEGER NOT NULL,
        owner_uid TEXT NOT NULL,
        request_id TEXT NOT NULL,
        handled INTEGER NOT NULL DEFAULT 0,
        notified INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (meal_id, planned_at)
      )
    ''');

class ScheduledMealDecisionJournal {
  const ScheduledMealDecisionJournal(this.db);

  final DatabaseImpl db;

  Future<ScheduledMealDecision?> load(int mealId, DateTime plannedAt) async {
    final row = await db
        .customSelect(
          'SELECT owner_uid, request_id, handled FROM scheduled_meal_decision '
          'WHERE meal_id=? AND planned_at=?',
          variables: [
            Variable(mealId),
            Variable(plannedAt.millisecondsSinceEpoch),
          ],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : (
            uid: row.read<String>('owner_uid'),
            requestId: row.read<String>('request_id'),
            handled: row.read<bool>('handled'),
          );
  }

  Future<void> remember(
    int mealId,
    DateTime plannedAt, {
    required String uid,
    required String requestId,
  }) => db.customStatement(
    'INSERT INTO scheduled_meal_decision (meal_id, planned_at, owner_uid, request_id) '
    'VALUES (?,?,?,?) ON CONFLICT(meal_id, planned_at) DO UPDATE SET '
    'request_id=excluded.request_id WHERE owner_uid=excluded.owner_uid AND handled=0',
    [mealId, plannedAt.millisecondsSinceEpoch, uid, requestId],
  );

  Future<void> complete(
    int mealId,
    DateTime plannedAt, {
    bool notified = false,
  }) => db.customStatement(
    'UPDATE scheduled_meal_decision SET handled=1, notified=? WHERE meal_id=? AND planned_at=?',
    [notified ? 1 : 0, mealId, plannedAt.millisecondsSinceEpoch],
  );

  Future<void> cleanNotifications({
    required String? uid,
    required DateTime now,
    required Future<void> Function(String requestId) cancel,
    bool keepManualNotices = true,
  }) async {
    final rows = await db
        .customSelect(
          '''
      WITH entries AS (
        SELECT journal.meal_id, journal.planned_at, journal.owner_uid,
          journal.request_id, journal.notified,
          (journal.owner_uid IS NOT ? OR meal.id IS NULL
           OR meal.planned_at IS NOT journal.planned_at OR meal.status <> 'planned'
           OR meal.purpose <> 'meal' OR journal.planned_at < ?) AS stale
        FROM scheduled_meal_decision AS journal
        LEFT JOIN meal ON meal.id=journal.meal_id
      )
      SELECT * FROM entries WHERE stale OR (? AND notified=1)
      ''',
          variables: [
            Variable(uid),
            Variable(
              now
                  .subtract(scheduledMealDecisionRecoveryWindow)
                  .millisecondsSinceEpoch,
            ),
            Variable(!keepManualNotices),
          ],
        )
        .get();
    for (final row in rows) {
      final requestId = row.read<String>('request_id');
      await cancel(requestId);
      final operation = row.read<bool>('stale')
          ? 'DELETE FROM scheduled_meal_decision'
          : 'UPDATE scheduled_meal_decision SET notified=0';
      await db.customStatement(
        '$operation WHERE meal_id=? AND planned_at=? AND owner_uid=? AND request_id=?',
        [
          row.read<int>('meal_id'),
          row.read<int>('planned_at'),
          row.read<String>('owner_uid'),
          requestId,
        ],
      );
    }
  }
}
