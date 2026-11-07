import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';
import '../family_sync/family_workflow_guard.dart';
import 'activity_activation_guard.dart';

/// Shared transaction-local rules for UI and authenticated caregiver proposals.
Future<ActivityLogData> insertActivitySession(
  DatabaseImpl db, {
  required int activityId,
  required DateTime start,
  DateTime? end,
}) async {
  final now = clock.now();
  if (end != null && (!end.isAfter(start) || end.isAfter(now))) {
    throw ArgumentError(
      'Historical activity must end after its start and not in the future',
    );
  }
  await ensureActivityActivationAllowed(
    db,
    startsAt: start,
    endsAt: end,
    now: now,
  );
  if (end == null && !start.isAfter(now)) {
    if (await FamilyWorkflowGuard(db).persistedAny('activity')) {
      throw StateError('An activity is already in progress');
    }
  }
  return db.activityDao.insertActivityLog(
    ActivityLogCompanion.insert(
      activityId: activityId,
      startedAt: start.millisecondsSinceEpoch,
      endedAt: Value(end?.millisecondsSinceEpoch),
    ),
  );
}
