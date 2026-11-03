import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'meal_calculator_evidence.dart';

class MealCalculatorRequest {
  MealCalculatorRequest({
    required this.event,
    required this.openedAt,
    this.sessionId,
    this.contextRequestedAt,
    Map<String, dynamic>? evidence,
  }) : tracker = MealCalculatorEvidence(event: event, openedAt: openedAt) {
    if (evidence != null) tracker.update(evidence);
  }

  final AapsBolusSuggestionNotificationEvent event;
  final DateTime openedAt;
  final DateTime? contextRequestedAt;
  String? sessionId;
  final MealCalculatorEvidence tracker;
  bool instructionNotificationCleared = false;
  bool acceptedByMeal = false;
  List<int> acceptedWizardTimes = [];

  List<bool> get completedRows => [
    tracker.bolusConfirmed,
    if (event.extendedCarbs > 0) tracker.extendedCarbsConfirmed,
    if (event.extendedCarbs > 0 &&
        event.extendedCarbsDelayMinutes != null &&
        event.extendedCarbsDurationMinutes != null)
      tracker.extendedCarbsConfirmed,
  ];

  Map<String, dynamic> toJson() => {
    'event': event.toJson(),
    'openedAt': openedAt.millisecondsSinceEpoch,
    'sessionId': sessionId,
    'contextRequestedAt': contextRequestedAt?.millisecondsSinceEpoch,
    'evidence': tracker.evidence,
    'instructionNotificationCleared': instructionNotificationCleared,
    'acceptedByMeal': acceptedByMeal,
    'acceptedWizardTimes': acceptedWizardTimes,
  };

  factory MealCalculatorRequest.fromJson(Map<String, dynamic> json) {
    final request = MealCalculatorRequest(
      event: AapsBolusSuggestionNotificationEvent.fromPayload(
        Map<String, dynamic>.from(json['event'] as Map),
      ),
      openedAt: DateTime.fromMillisecondsSinceEpoch(json['openedAt'] as int),
      sessionId: json['sessionId'] as String?,
      contextRequestedAt: json['contextRequestedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              json['contextRequestedAt'] as int,
            ),
      evidence: Map<String, dynamic>.from(json['evidence'] as Map),
    );
    request.instructionNotificationCleared =
        json['instructionNotificationCleared'] as bool? ?? false;
    request.acceptedByMeal = json['acceptedByMeal'] as bool? ?? false;
    request.acceptedWizardTimes =
        (json['acceptedWizardTimes'] as List?)?.cast<int>() ?? [];
    return request;
  }
}
