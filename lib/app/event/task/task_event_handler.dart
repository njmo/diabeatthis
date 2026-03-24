import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/logger.dart';
import '../../../core/notifications/domain/events/notification_event_factory.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../bridge/data_synchronization_bridge.dart';
import 'task_event.dart';

class TaskEventHandler with Logging {
  final WidgetRef _ref;
  final DataSynchronizationBridge synchronizationDataBridge;

  TaskEventHandler(this._ref) : synchronizationDataBridge = DataSynchronizationBridge(_ref);

  void handle(Map<String, dynamic> event) {
    final appEvent = TaskEvent.fromJson(event);

    switch(appEvent)
    {
      case TaskInAppNotificationEvent(data: final payload):
        logI('Showing notification: $payload');

        final event = NotificationEventFactory()
            .fromPayload(payload.type, payload.data);
        _ref.read(notificationsControllerUiProvider).show(event);
        break;
      case TaskDataSynchronizationEvent(data: final payload):
        synchronizationDataBridge.handle(payload);
        break;
    }
  }
}
