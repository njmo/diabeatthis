import '../../../../common/monitoring/is_temporary_target_active.dart';
import '../../../../common/temporary_targets/is_activity_temp_target_linked.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/data/drafts/activity_log_draft.dart';

class AttachActivityToTargetUseCase {
  const AttachActivityToTargetUseCase({
    required this.now,
    required this.currentTarget,
    required this.saveStartedActivity,
  });
  final DateTime Function() now;
  final TemporaryTarget? Function() currentTarget;
  final Future<void> Function(ActivityLogDraft draft) saveStartedActivity;

  Future<void> call(TemporaryTarget target, ActivityLogDraft draft) async {
    if (currentTarget() != target ||
        !isTemporaryTargetActive(target, at: now()) ||
        !isActivityTempTarget(target)) {
      throw StateError('The activity target changed or expired');
    }
    await saveStartedActivity(draft);
  }
}
