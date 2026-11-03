import '../../../../common/monitoring/is_temporary_target_active.dart';
import '../../../../core/domain/model/temporary_target.dart';

enum DashboardTargetActionResult { sent, disabled, changed, failed }

class StopDashboardTargetUseCase {
  const StopDashboardTargetUseCase({
    required this.now,
    required this.currentTarget,
    required this.canControl,
    required this.stop,
  });
  final DateTime Function() now;
  final TemporaryTarget? Function() currentTarget;
  final bool Function() canControl;
  final Future<DashboardTargetActionResult> Function(TemporaryTarget target)
  stop;

  Future<DashboardTargetActionResult> call(TemporaryTarget target) async {
    if (!canControl()) return DashboardTargetActionResult.disabled;
    if (currentTarget() != target ||
        !isTemporaryTargetActive(target, at: now())) {
      return DashboardTargetActionResult.changed;
    }
    return stop(target);
  }
}
