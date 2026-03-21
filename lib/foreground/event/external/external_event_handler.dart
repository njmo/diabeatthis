import '../../task/base/runtime_context.dart';
import 'app/app_event_handler.dart';
import 'external_event.dart';
import 'notification/notification_response_event_handler.dart';

class ExternalEventHandler {
  final RuntimeContext _runtimeContext;
  final AppEventHandler _appEventHandler;
  final NotificationResponseEventHandler _notificationResponseEventHandler;

  ExternalEventHandler(this._runtimeContext)
    : _appEventHandler = AppEventHandler(),
      _notificationResponseEventHandler = NotificationResponseEventHandler();

  void handle(Map<String, dynamic> event) {
    final externalEvent = ExternalEvent.fromJson(event);

    externalEvent.when(
      appEvent: (data) => _appEventHandler.handle(data, _runtimeContext),
      notificationEvent: (data) =>
          _notificationResponseEventHandler.handle(data, _runtimeContext),
    );
  }
}
