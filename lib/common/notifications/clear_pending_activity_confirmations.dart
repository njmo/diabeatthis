import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';

/// Notification cleanup is local and must survive sign-out or disabled sharing.
/// The same transaction serializes cleanup and replacement prompt delivery.
Future<void> clearPendingActivityConfirmations(
  DatabaseImpl db,
  int occurrenceId,
  Future<void> Function(int) cancel,
) => db.transaction(() async {
  final pending = await db
      .customSelect(
        'SELECT 1 FROM family_plan_journal WHERE cancel_occurrence_id=? AND notification_cleared=0 UNION ALL SELECT 1 FROM family_plan_notification_cancellations WHERE occurrence_id=? AND cleared=0 LIMIT 1',
        variables: [Variable(occurrenceId), Variable(occurrenceId)],
      )
      .get();
  if (pending.isEmpty) return;
  await cancel(occurrenceId);
  await db.customUpdate(
    'UPDATE family_plan_journal SET notification_cleared=1 WHERE cancel_occurrence_id=? AND notification_cleared=0',
    variables: [Variable(occurrenceId)],
    updates: {db.activityOccurrence},
  );
  await db.customUpdate(
    'UPDATE family_plan_notification_cancellations SET cleared=1 WHERE occurrence_id=? AND cleared=0',
    variables: [Variable(occurrenceId)],
    updates: {db.activityOccurrence},
  );
});
