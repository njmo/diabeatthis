import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get finishedEatingNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.finishedEating,
      categoryId: 'finished_eating',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationActionFinishedEating,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.snooze,
          label: lang.notificationActionNotYet,
        ),
      ],
      channelType: NotificationChannelType.meal,
    );
