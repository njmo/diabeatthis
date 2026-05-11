import '../../../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';
import 'activity_monitor_state_executor.dart';
import 'new_activity_check_executor.dart';

class FinishActivityExecutor extends ActivityMonitorStateExecutor {
  const FinishActivityExecutor();

  @override
  List<Type> get interruptableEvents => [];

  @override
  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("FinishActivityExecutor cleanup");
  }

  @override
  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  ) async {
    logI("FinishActivityExecutor");
    activityMonitorContext.clear();

    await runtimeContext.container
        .read(notificationsControllerForegroundProvider)
        .cancelAll();

    return const NewActivityCheckExecutor();
  }
}
