import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get activityScheduleNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.activitySchedule,
      categoryId: 'activity_schedule',
      actions: [
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.activityScheduleYes,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.skip,
          label: lang.activityScheduleNo,
        ),
      ],
      channelType: NotificationChannelType.activity,
    );
