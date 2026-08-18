import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_input_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get mealSuggestionNotificationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.mealSuggestion,
      categoryId: 'meal_suggestion',
      actions: <NotificationActionDef>[
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationActionApprove,
        ),
        NotificationActionDef.text(
          type: NotificationActionType.snooze,
          label: lang.notificationActionSnooze,
          inputActionDef: NotificationActionInputDef(
            title: lang.notificationSnoozeInputTitle,
            placeholderText: lang.notificationSnoozeInputPlaceholder,
          ),
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.skip,
          label: lang.notificationActionSkipMeal,
        ),
      ],
      channelType: NotificationChannelType.meal,
    );
