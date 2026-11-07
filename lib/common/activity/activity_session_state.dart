import 'package:clock/clock.dart';

enum ActivitySessionState { planned, active, finished }

ActivitySessionState activitySessionState({
  required DateTime startedAt,
  required DateTime? endedAt,
  DateTime? now,
}) {
  if (endedAt != null) return ActivitySessionState.finished;
  return startedAt.isAfter(now ?? clock.now())
      ? ActivitySessionState.planned
      : ActivitySessionState.active;
}
