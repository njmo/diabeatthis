import 'package:clock/clock.dart';

import '../../../../../common/monitoring/activity_monitoring_phase.dart';
import '../../../../event/internal/activity_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import '../helpers/activity_temp_target_monitor.dart';
import 'activity_monitor_state_executor.dart';

class ActivityMonitorStateIdle extends ActivityMonitorStateExecutor {
  const ActivityMonitorStateIdle();

  @override
  List<Type> get interruptableEvents => [
    NextActivityEvent,
    ActivityStartedEvent,
  ];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("ActivityMonitorStateIdle cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    activityMonitorContext.publishStatus(
      runtimeContext,
      ActivityMonitoringPhase.idle,
    );
    logI("ActivityMonitorStateIdle");
    final targets = runtimeContext.container.read(
      activityTempTargetMonitorProvider,
    );
    if (await targets.isEnabled(runtimeContext)) {
      await targets.waitUntil(
        runtimeContext,
        clock.now().add(const Duration(minutes: 15)),
      );
    } else {
      await runtimeContext.waitForDuration(const Duration(minutes: 15));
    }
    return this;
  }
}
