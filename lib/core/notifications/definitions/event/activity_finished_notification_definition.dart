import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const activityFinishedNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.activityFinished,
  categoryId: 'activity_finished',
  actions: <NotificationActionDef>[
    NotificationActionDef.plain(
      type: NotificationActionType.agree,
      label: 'Zakończ trening',
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.dismiss,
      label: 'Zakończę ręcznie',
    ),
  ],
  channelType: NotificationChannelType.activity,
);
