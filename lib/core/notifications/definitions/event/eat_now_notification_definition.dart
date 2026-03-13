import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const mealReadyNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.eatNow,
  categoryId: 'eat_now',
  actions: <NotificationActionDef>[
    NotificationActionDef(type: NotificationActionType.eating, label: 'Zaczynam jeść ✅'),
    NotificationActionDef(type: NotificationActionType.dismiss, label: 'Jeszcze nie'),
  ],
  channelType: NotificationChannelType.meal,
);
