import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const finishedEatingNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.finishedEating,
  categoryId: 'finished_eating',
  actions: <NotificationActionDef>[
    NotificationActionDef.plain(type: NotificationActionType.agree, label: 'Skończyłem jeść ✅'),
    NotificationActionDef.plain(type: NotificationActionType.snooze, label: 'Jeszcze nie'),
  ],
  channelType: NotificationChannelType.meal,
);
