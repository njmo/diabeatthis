import '../../../../../core/logger/logger.dart';
import '../../../../event/internal/activity_event.dart';
import '../../../../event/model/foreground_event.dart';
import '../../../base/runtime_context.dart';
import '../activity_monitor_context.dart';

abstract class ActivityMonitorStateExecutor with Logging {
  const ActivityMonitorStateExecutor();

  String get name => runtimeType.toString();

  List<Type> get interruptableEvents => [
    NextActivityEvent,
    ActivityStartedEvent,
    ActivityStoppedEvent,
    ActivityCancelledEvent,
  ];

  bool shouldInterrupt(
    ForegroundEvent event,
    ActivityMonitorContext activityMonitorContext,
  ) {
    logI("ActivityMonitorStateExecutor shouldInterrupt ${event.runtimeType}");
    return true;
  }

  Future<ActivityMonitorStateExecutor> execute(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  );

  Future<void> cleanup(
    RuntimeContext runtimeContext,
    ActivityMonitorContext activityMonitorContext,
  );
}
