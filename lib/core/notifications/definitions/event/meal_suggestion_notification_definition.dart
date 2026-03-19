import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_input_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const mealSuggestionNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.mealSuggestion,
  categoryId: 'meal_suggestion',
  actions: <NotificationActionDef>[
    NotificationActionDef.plain(
      type: NotificationActionType.agree,
      label: 'Zatwierdzam',
    ),
    NotificationActionDef.text(
      type: NotificationActionType.snooze,
      label: 'Opóznij',
      inputActionDef: NotificationActionInputDef(
        title: 'Na jak długo?',
        placeholderText: 'Wpisz tutaj czas',
      ),
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.skip,
      label: 'Pomiń posiłek',
    ),
  ],
  channelType: NotificationChannelType.meal,
);
