import '../../../task/base/runtime_context.dart';
import 'app_event.dart';

class AppEventHandler {
  AppEventHandler();

  void handle(AppEvent event, RuntimeContext runtimeContext) {
    event.when(
      appLifecycleState: (final data) {
        runtimeContext.emitEvent(data);
      },
    );
  }
}
