import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../domain/models/meal_ai_invalid_response.dart';
import '../../domain/models/meal_dml_document.dart';
import '../../domain/services/meal_ai_client.dart';
import '../prompts/meal_ai_prompt.dart';

class LlmMealAiClient implements MealAiClient {
  final LocalLlmClient transport;
  @override
  final String modelId;
  final Duration timeout;
  const LlmMealAiClient({
    required this.transport,
    required this.modelId,
    this.timeout = const Duration(seconds: 60),
  });
  @override
  Future<({String prompt, String text})> analyze(
    MealDmlDocument document, {
    required String language,
  }) async {
    if (language != 'pl' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    final prompt = buildMealAiPrompt(document, language);
    try {
      final response = await transport
          .generate(LocalLlmRequest(prompt: prompt, timeout: timeout))
          .timeout(timeout);
      return (prompt: prompt, text: response.text);
    } on LlmOutputLimitException catch (error) {
      throw MealAiInvalidResponse(error.response, tokenLimitReached: true);
    }
  }
}
