import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class AapsBolusSuggestionNotificationEvent implements NotificationEvent {
  const AapsBolusSuggestionNotificationEvent({
    required this.mealId,
    required this.mealName,
    required this.carbs,
    required this.status,
    this.waitMinutes,
    this.extendedCarbs = 0,
    this.extendedCarbsDeliveryMode = ExtendedCarbsDeliveryMode.extendedCarbs,
    this.extendedCarbsDelayMinutes = 45,
    this.extendedCarbsDurationMinutes = 120,
  });

  final int mealId;
  final String mealName;
  final int carbs;
  final String status;
  final int? waitMinutes;
  final int extendedCarbs;
  final ExtendedCarbsDeliveryMode extendedCarbsDeliveryMode;
  final int extendedCarbsDelayMinutes;
  final int extendedCarbsDurationMinutes;

  @override
  NotificationEventType get type => NotificationEventType.aapsBolusSuggestion;

  @override
  String get notificationResponseEvent => 'aaps_bolus_suggestion';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: mealId);

  @override
  String get title => _calculatorInstruction;

  @override
  String get body => '';

  String get _calculatorInstruction {
    final carbsText = '${carbs}g';
    final extendedCarbsText = extendedCarbs > 0
        ? ' i ${extendedCarbs}g za '
              '${formatExtendedCarbsScheduleMinutes(extendedCarbsDelayMinutes)}'
              ' przez ${formatExtendedCarbsScheduleMinutes(extendedCarbsDurationMinutes)}'
        : '';

    return 'Podaj $carbsText teraz$extendedCarbsText';
  }

  @override
  Map<String, Object?> toPayload() => const {};

  @override
  Map<String, Object?> toJson() => {
    'mealId': mealId,
    'mealName': mealName,
    'carbs': carbs,
    'status': status,
    'waitMinutes': waitMinutes,
    'extendedCarbs': extendedCarbs,
    'extendedCarbsDeliveryMode': extendedCarbsDeliveryMode.name,
    'extendedCarbsDelayMinutes': extendedCarbsDelayMinutes,
    'extendedCarbsDurationMinutes': extendedCarbsDurationMinutes,
  };

  factory AapsBolusSuggestionNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return AapsBolusSuggestionNotificationEvent(
      mealId: json['mealId'] as int,
      mealName: json['mealName'] as String,
      carbs: json['carbs'] as int,
      status: json['status'] as String,
      waitMinutes: json['waitMinutes'] as int?,
      extendedCarbs: json['extendedCarbs'] as int? ?? 0,
      extendedCarbsDeliveryMode: _deliveryModeFromJson(
        json['extendedCarbsDeliveryMode'] as String?,
      ),
      extendedCarbsDelayMinutes:
          json['extendedCarbsDelayMinutes'] as int? ?? 45,
      extendedCarbsDurationMinutes:
          json['extendedCarbsDurationMinutes'] as int? ?? 120,
    );
  }
}

ExtendedCarbsDeliveryMode _deliveryModeFromJson(String? value) {
  return ExtendedCarbsDeliveryMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ExtendedCarbsDeliveryMode.extendedCarbs,
  );
}
