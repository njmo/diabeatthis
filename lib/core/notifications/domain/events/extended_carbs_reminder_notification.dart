import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';
import 'aaps_bolus_suggestion_notification.dart';

/// Reminds the child once that the planned eCarbs are still missing in AAPS.
/// The delay counts from now, so entering it as shown starts on schedule.
class ExtendedCarbsReminderNotificationEvent implements NotificationEvent {
  const ExtendedCarbsReminderNotificationEvent({
    required this.mealId,
    required this.extendedCarbs,
    required this.delayMinutes,
    required this.durationMinutes,
    this.additional = false,
  });

  final int mealId;
  final int extendedCarbs;
  final int delayMinutes;
  final int durationMinutes;
  final bool additional;

  @override
  NotificationEventType get type => NotificationEventType.extendedCarbsReminder;

  @override
  String get notificationResponseEvent => '';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => lang.notificationExtendedCarbsReminderTitle;

  @override
  String get body => AapsBolusSuggestionNotificationEvent(
    mealId: mealId,
    carbs: 0,
    extendedCarbs: extendedCarbs,
    extendedCarbsAreAdditional: additional,
    extendedCarbsDelayMinutes: delayMinutes,
    extendedCarbsDurationMinutes: durationMinutes,
  ).title;

  @override
  Map<String, Object?> toPayload() => {};

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'extendedCarbs': extendedCarbs,
    'delayMinutes': delayMinutes,
    'durationMinutes': durationMinutes,
    if (additional) 'additional': true,
  };

  factory ExtendedCarbsReminderNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return ExtendedCarbsReminderNotificationEvent(
      mealId: json['mealId'] as int,
      extendedCarbs: json['extendedCarbs'] as int,
      delayMinutes: json['delayMinutes'] as int,
      durationMinutes: json['durationMinutes'] as int,
      additional: json['additional'] as bool? ?? false,
    );
  }
}
