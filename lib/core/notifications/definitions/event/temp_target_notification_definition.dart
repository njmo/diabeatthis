import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get tempTargetNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.tempTarget,
      categoryId: 'temp_target',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationActionApprove,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.dismiss,
          label: lang.notificationActionReject,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.skip,
          label: lang.notificationActionSkip,
        ),
      ],
      channelType: NotificationChannelType.target,
    );
