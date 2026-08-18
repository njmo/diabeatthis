import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get activityFinishedNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.activityFinished,
      categoryId: 'activity_finished',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationActionFinishActivity,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.dismiss,
          label: lang.notificationActionFinishManually,
        ),
      ],
      channelType: NotificationChannelType.activity,
    );
