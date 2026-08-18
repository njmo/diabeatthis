import '../base/notification_definition_catalog.dart';
import '../domain/models/notification_definition.dart';
import '../domain/models/notification_event_type.dart';
import 'event/aaps_bolus_suggestion_notification_definition.dart';
import 'event/activity_finished_notification_definition.dart';
import 'event/eat_now_notification_definition.dart';
import 'event/finished_eating_notification_definition.dart';
import 'event/meal_advice_pending_notification_definition.dart';
import 'event/meal_suggestion_notification_definition.dart';
import 'event/meal_summary_reminder_notification_definition.dart';
import 'event/temp_target_notification_definition.dart';

class NotificationDefinitionCatalogImpl
    implements NotificationDefinitionCatalog {
  List<NotificationDefinition> get _definitions => [
    mealReadyNotificationDefinition,
    tempTargetNotificationDefinition,
    mealSuggestionNotificationDefinition,
    mealAdvicePendingNotificationDefinition,
    finishedEatingNotificationDefinition,
    activityFinishedNotificationDefinition,
    mealSummaryReminderNotificationDefinition,
    aapsBolusSuggestionNotificationDefinition,
  ];

  @override
  NotificationDefinition byType(NotificationEventType type) {
    return _definitions.firstWhere((d) => d.type == type);
  }

  @override
  List<NotificationDefinition> get all => _definitions;
}
