import '../../../../common/meal/meal_decision.dart';

enum MealAdvisorSuggestionStatus { suggestion, insufficientData }

/// A validated draft, never a command to deliver insulin or start a meal.
class MealAdvisorSuggestion {
  final String requestId;
  final MealAdvisorSuggestionStatus status;
  final MealDecision? action;
  final int? waitMinutes;
  final String reason;
  final List<String> evidence;
  final List<String> missingData;

  MealAdvisorSuggestion({
    required this.requestId,
    required this.status,
    required this.action,
    required this.waitMinutes,
    required this.reason,
    required List<String> evidence,
    required List<String> missingData,
  }) : evidence = List.unmodifiable(evidence),
       missingData = List.unmodifiable(missingData);
}
