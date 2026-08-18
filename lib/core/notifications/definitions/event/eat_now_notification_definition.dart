import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get mealReadyNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.eatNow,
      categoryId: 'eat_now',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.eating,
          label: lang.notificationActionStartEating,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.dismiss,
          label: lang.notificationActionNotYet,
        ),
      ],
      channelType: NotificationChannelType.meal,
    );
