import 'meal_advisor_context.dart';

class MealAdvisorInput {
  final MealAdvisorContext context;
  final String requestId;
  final String text;
  final Set<String> evidenceIds;
  MealAdvisorInput({
    required this.context,
    required this.requestId,
    required this.text,
    required Set<String> evidenceIds,
  }) : evidenceIds = Set.unmodifiable(evidenceIds);
}
