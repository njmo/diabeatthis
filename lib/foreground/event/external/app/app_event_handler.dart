import '../../../runtime/workflow_scheduler.dart';
import 'app_event.dart';

class AppEventHandler {
  final WorkflowScheduler _workflowScheduler;

  AppEventHandler(this._workflowScheduler);

  void handle(AppEvent event) {
    event.when(
      appLifecycleState: (final data) {
        _workflowScheduler.emitEvent(data);
      },
    );
  }
}
