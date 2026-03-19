import '../../event/model/foreground_event.dart';
import '../../runtime/task_interrupted_exception.dart';
import 'runtime_context.dart';

abstract class WorkflowTask {
  const WorkflowTask();

  String get name => runtimeType.toString();

  bool get interruptable => false;

  Future<void> run(RuntimeContext context);
}

abstract class InterruptableWorkflowTask extends WorkflowTask {
  @override
  bool get interruptable => true;

  List<bool Function(ForegroundEvent)> get interruptableEventsMatcher => [
  ];

  bool shouldInterrupt(ForegroundEvent event) {
    return false;
  }

  Future<void> runLoop(
      RuntimeContext context, {
        ForegroundEvent? interruptedEvent,
      });

  Future<ForegroundEvent?> onInterrupted(
      RuntimeContext context,
      ForegroundEvent event,
      ) async {
    return event;
  }

  @override
  Future<void> run(RuntimeContext context) async {
    ForegroundEvent? resumeFrom;

    while (!context.isCancelled) {
      try {
        context.interruptController.reset();
        await runLoop(context, interruptedEvent: resumeFrom);
        resumeFrom = null;
      } on TaskInterruptedException catch (e) {
        context.log('$name interrupted by ${e.event.runtimeType}');
        resumeFrom = await onInterrupted(context, e.event);
        continue;
      }
    }
  }
}
