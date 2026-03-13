import '../../../runtime/event_dispatcher.dart';
import 'app_event.dart';

class AppEventHandler {
  final EventDispatcher _dispatcher;

  AppEventHandler(this._dispatcher);

  void handle(AppEvent event) {
    event.when(
      appLifecycleState: (final data) {
        _dispatcher.dispatch(data);
      },
    );
  }
}
