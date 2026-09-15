import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class MealAdvicePendingNotificationEvent implements NotificationEvent {
  const MealAdvicePendingNotificationEvent({
    required this.mealId,
    this.unavailable = false,
  });

  final bool unavailable;

  final int mealId;

  @override
  NotificationEventType get type => NotificationEventType.mealAdvicePending;

  @override
  String get notificationResponseEvent => '';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => unavailable
      ? lang.mealAdviceUnavailableTitle
      : lang.notificationMealAdvicePendingTitle;

  @override
  String get body => unavailable
      ? lang.mealPendingAdviceUnavailable
      : lang.notificationMealAdvicePendingBody;

  @override
  Map<String, Object?> toPayload() => {};

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'unavailable': unavailable,
  };

  factory MealAdvicePendingNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return MealAdvicePendingNotificationEvent(
      mealId: json['mealId'] as int,
      unavailable: json['unavailable'] as bool? ?? false,
    );
  }
}
