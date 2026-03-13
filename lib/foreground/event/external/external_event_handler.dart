import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/event_dispatcher.dart';
import 'app/app_event_handler.dart';
import 'external_event.dart';
import 'notification/notification_response_event_handler.dart';

class ExternalEventHandler {
  final AppEventHandler _appEventHandler;
  final NotificationResponseEventHandler _notificationResponseEventHandler;

  ExternalEventHandler(container, dispatcher)
    : _appEventHandler = AppEventHandler(dispatcher),
      _notificationResponseEventHandler = NotificationResponseEventHandler(
        container,
        dispatcher,
      );

  void handle(Map<String, dynamic> event) {
    final externalEvent = ExternalEvent.fromJson(event);

    externalEvent.when(
      appEvent: (data) => _appEventHandler.handle(data),
      notificationEvent: (data) =>
          _notificationResponseEventHandler.handle(data),
    );
  }
}
