import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const tempTargetNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.tempTarget,
  categoryId: 'temp_target',
  actions: <NotificationActionDef>[
  ],
  channelType: NotificationChannelType.target,
);
