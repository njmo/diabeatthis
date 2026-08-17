import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const mealAdvicePendingNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.mealAdvicePending,
  categoryId: 'meal_advice_pending',
  actions: <NotificationActionDef>[],
  channelType: NotificationChannelType.meal,
);
