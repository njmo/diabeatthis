import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const extendedCarbsReminderNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.extendedCarbsReminder,
  categoryId: 'extended_carbs_reminder',
  actions: <NotificationActionDef>[],
  channelType: NotificationChannelType.aapsSuggestion,
);
