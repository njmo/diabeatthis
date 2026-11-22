import '../../../../common/l10n/language.dart';
import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_input_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

NotificationDefinition get plannedMealConfirmationDefinition =>
    NotificationDefinition(
      type: NotificationEventType.plannedMealConfirmation,
      categoryId: 'planned_meal_confirmation',
      channelType: NotificationChannelType.meal,
      actions: [
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.notificationPlannedMealYes,
        ),
        NotificationActionDef.text(
          type: NotificationActionType.snooze,
          label: lang.mealDecisionDefer,
          inputActionDef: NotificationActionInputDef(
            title: lang.mealDecisionDeferralMinutes,
            placeholderText: '30',
            minuteStep: 5,
          ),
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.skip,
          label: lang.settingsCancel,
        ),
      ],
    );

NotificationDefinition get plannedMealAdviceDefinition =>
    NotificationDefinition(
      type: NotificationEventType.plannedMealAdvice,
      categoryId: 'planned_meal_advice',
      channelType: NotificationChannelType.meal,
      actions: [
        NotificationActionDef.plain(
          type: NotificationActionType.agree,
          label: lang.mealDecisionDemoAccept,
        ),
        NotificationActionDef.plain(
          type: NotificationActionType.skip,
          label: lang.notificationActionReject,
        ),
      ],
    );
