import '../../../../common/l10n/language.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_formatter.dart';
import '../../../../features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class AapsBolusSuggestionNotificationEvent implements NotificationEvent {
  const AapsBolusSuggestionNotificationEvent({
    required this.carbs,
    this.extendedCarbs = 0,
    this.extendedCarbsDeliveryMode,
    this.extendedCarbsDelayMinutes,
    this.extendedCarbsDurationMinutes,
  });

  final int carbs;
  final int extendedCarbs;
  // TODO: Use delivery mode when rendering e-carbs text once MealAdvisor
  // supports shifted bolus recommendations for extended carbs. Today the
  // notification text only renders delay/duration.
  final ExtendedCarbsDeliveryMode? extendedCarbsDeliveryMode;
  final int? extendedCarbsDelayMinutes;
  final int? extendedCarbsDurationMinutes;

  @override
  NotificationEventType get type => NotificationEventType.aapsBolusSuggestion;

  @override
  String get notificationResponseEvent => 'aaps_bolus_suggestion';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: 0);

  @override
  String get title => _calculatorInstruction;

  @override
  String get body => '';

  String get _calculatorInstruction {
    final carbsText = '${carbs}g';
    final extendedCarbsText = extendedCarbs > 0
        ? lang.notificationExtendedCarbsInline(_extendedCarbsScheduleText())
        : '';

    if (carbs == 0) {
      if (extendedCarbs <= 0) {
        throw StateError('AAPS suggestion requires carbs or extended carbs.');
      }

      return lang.notificationAapsSuggestionEnterExtended(
        _extendedCarbsScheduleText(),
      );
    }

    if (carbs <= 0) {
      return lang.notificationAapsSuggestionEnterCarbs(
        carbsText,
        extendedCarbsText,
      );
    }

    return lang.notificationAapsSuggestionDeliverCarbs(
      carbsText,
      extendedCarbsText,
    );
  }

  String _extendedCarbsScheduleText() {
    if (extendedCarbs <= 0) {
      throw StateError('AAPS suggestion has no extended carbs schedule.');
    }

    final delayMinutes = extendedCarbsDelayMinutes;
    final durationMinutes = extendedCarbsDurationMinutes;
    if (delayMinutes == null || durationMinutes == null) {
      throw StateError('AAPS extended carbs suggestion requires schedule.');
    }

    return lang.notificationExtendedCarbsSchedule(
      extendedCarbs,
      formatExtendedCarbsScheduleMinutes(delayMinutes),
      formatExtendedCarbsScheduleMinutes(durationMinutes),
    );
  }

  @override
  Map<String, Object?> toPayload() => const {};

  @override
  Map<String, Object?> toJson() => {
    'carbs': carbs,
    'extendedCarbs': extendedCarbs,
    'extendedCarbsDeliveryMode': extendedCarbsDeliveryMode?.name,
    'extendedCarbsDelayMinutes': extendedCarbsDelayMinutes,
    'extendedCarbsDurationMinutes': extendedCarbsDurationMinutes,
  };

  factory AapsBolusSuggestionNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) {
    return AapsBolusSuggestionNotificationEvent(
      carbs: json['carbs'] as int,
      extendedCarbs: json['extendedCarbs'] as int? ?? 0,
      extendedCarbsDeliveryMode: _deliveryModeFromJson(
        json['extendedCarbsDeliveryMode'] as String?,
      ),
      extendedCarbsDelayMinutes: json['extendedCarbsDelayMinutes'] as int?,
      extendedCarbsDurationMinutes:
          json['extendedCarbsDurationMinutes'] as int?,
    );
  }
}

ExtendedCarbsDeliveryMode? _deliveryModeFromJson(String? value) {
  if (value == null) {
    return null;
  }

  return ExtendedCarbsDeliveryMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ExtendedCarbsDeliveryMode.extendedCarbs,
  );
}
