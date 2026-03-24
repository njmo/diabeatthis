import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/notification_event_factory.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import 'task_event.dart';

class TaskEventHandler with Logging {
  final WidgetRef _ref;

  TaskEventHandler(this._ref);

  void handle(Map<String, dynamic> event) {
    final appEvent = TaskEvent.fromJson(event);

    switch(appEvent)
    {
      case TaskInAppNotificationEvent(data: final payload):
        logI('Showing notification: $payload');

        final event = NotificationEventFactory()
            .fromPayload(payload.type, payload.data);
        _ref.read(notificationsControllerUiProvider).show(event);
    }
  }
}
