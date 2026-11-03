import '../../core/drift/database_impl.dart';

/// Called inside the write transaction so concurrent UI actions cannot start
/// two sessions while the application exposes a single active activity.
Future<void> ensureActivityActivationAllowed(
  DatabaseImpl db, {
  required DateTime startsAt,
  required DateTime? endsAt,
  required DateTime now,
}) async {
  if (endsAt != null || startsAt.isAfter(now)) return;
  final open = await db.activityDao.getActiveActivityLogOrNull();
  if (open != null && open.startedAt <= now.millisecondsSinceEpoch) {
    throw StateError('An activity is already in progress');
  }
}
