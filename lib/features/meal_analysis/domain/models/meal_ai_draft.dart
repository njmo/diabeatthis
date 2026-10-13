import 'meal_ai_result.dart';
import 'meal_dml_document.dart';

class MealAiDraft {
  final MealDmlDocument document;
  final MealAiResult result;
  final String prompt;
  final String rawResponse;
  final String modelId;
  final DateTime generatedAt;
  final int promptVersion;
  const MealAiDraft({
    required this.document,
    required this.result,
    required this.prompt,
    required this.rawResponse,
    required this.modelId,
    required this.generatedAt,
    required this.promptVersion,
  });
}

class AcceptedMealAi {
  final MealAiDraft draft;
  final DateTime acceptedAt;
  const AcceptedMealAi({required this.draft, required this.acceptedAt});
}
