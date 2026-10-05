import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get aapsCarbsRequestNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.aapsCarbsRequest,
      categoryId: 'aaps_carbs_request',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationAapsCarbsRequestAcknowledge,
          openApp: false,
        ),
      ],
      channelType: NotificationChannelType.aapsSuggestion,
    );
