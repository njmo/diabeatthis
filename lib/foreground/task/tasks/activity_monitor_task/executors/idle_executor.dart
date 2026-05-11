import '../../../../event/internal/activity_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
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
    logI("ActivityMonitorStateIdle");
    await runtimeContext.waitForDuration(const Duration(minutes: 15));
    return this;
  }
}
