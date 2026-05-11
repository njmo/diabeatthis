import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const mealSummaryReminderNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.mealSummaryReminder,
  categoryId: 'meal_summary_reminder',
  actions: <NotificationActionDef>[
    NotificationActionDef.plain(
      type: NotificationActionType.agree,
      label: 'Zjadłem tyle co plan',
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.dismiss,
      label: 'OK',
    ),
  ],
  channelType: NotificationChannelType.meal,
);
