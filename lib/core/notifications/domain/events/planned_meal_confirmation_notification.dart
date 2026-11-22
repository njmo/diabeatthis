import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class PlannedMealConfirmationNotification implements NotificationEvent {
  const PlannedMealConfirmationNotification(
    this.mealId,
    this.plannedAtMs,
    this.name,
  );

  final int mealId;
  final int plannedAtMs;
  final String name;

  @override
  NotificationEventType get type =>
      NotificationEventType.plannedMealConfirmation;

  @override
  String get notificationResponseEvent => 'meal_suggestion_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => lang.notificationPlannedMealConfirmation;

  @override
  String get body => name;

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'mealId': mealId, 'plannedAtMs': plannedAtMs},
  };

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'plannedAtMs': plannedAtMs,
    'name': name,
  };

  factory PlannedMealConfirmationNotification.fromPayload(
    Map<String, dynamic> data,
  ) => PlannedMealConfirmationNotification(
    data['mealId'] as int,
    data['plannedAtMs'] as int,
    data['name'] as String,
  );
}
