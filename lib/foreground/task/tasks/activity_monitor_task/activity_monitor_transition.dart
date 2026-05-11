import 'activity_monitor_context.dart';
import 'executors/activity_monitor_state_executor.dart';

class ActivityMonitorTransition {
  final ActivityMonitorContext? context;
  final ActivityMonitorStateExecutor executor;

  ActivityMonitorTransition(this.context, this.executor);
}
