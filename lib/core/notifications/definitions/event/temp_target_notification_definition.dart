import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const tempTargetNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.tempTarget,
  categoryId: 'temp_target',
  actions: <NotificationActionDef>[
    NotificationActionDef.plain(
      type: NotificationActionType.agree,
      label: 'Zatwierdzam',
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.dismiss,
      label: 'Odrzuć',
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.skip,
      label: 'Pomiń',
    ),
  ],
  channelType: NotificationChannelType.target,
);
