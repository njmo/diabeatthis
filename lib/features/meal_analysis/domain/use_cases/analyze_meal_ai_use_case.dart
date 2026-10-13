import '../models/meal_ai_draft.dart';
import '../models/meal_ai_invalid_response.dart';
import '../models/meal_ai_result.dart';
import '../models/meal_dml_document.dart';
import '../services/meal_ai_client.dart';

class AnalyzeMealAiUseCase {
  final MealAiClient client;
  final DateTime Function() now;
  final int promptVersion;
  const AnalyzeMealAiUseCase({
    required this.client,
    required this.now,
    required this.promptVersion,
  });
  Future<MealAiDraft> call(
    MealDmlDocument document, {
    required String language,
  }) async {
    if (language != 'pl' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    final response = await client.analyze(document, language: language);
    final MealAiResult result;
    try {
      result = MealAiResult.parse(
        response.text,
        language: language,
        evidenceIds: document.evidenceIds,
        evidenceText: document.text,
      );
    } on FormatException {
      throw MealAiInvalidResponse(response.text);
    }
    return MealAiDraft(
      document: document,
      result: result,
      prompt: response.prompt,
      rawResponse: response.text,
      modelId: client.modelId,
      generatedAt: now(),
      promptVersion: promptVersion,
    );
  }
}
