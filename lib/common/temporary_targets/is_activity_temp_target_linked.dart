import '../../core/domain/model/temporary_target.dart';
import '../monitoring/is_temporary_target_active.dart';
import 'temp_target_policy.dart';

bool isActivityTempTarget(TemporaryTarget target) =>
    TempTargetPolicy.acceptsActivityTargetValue(target.targetTop);

/// This is a display association. Ownership used for cancellation is tracked
/// separately, so a manually set target is never cancelled by this heuristic.
bool isActivityTempTargetLinked({
  required bool activityVisible,
  required TemporaryTarget target,
  required DateTime now,
}) =>
    activityVisible &&
    isActivityTempTarget(target) &&
    isTemporaryTargetActive(target, at: now);
