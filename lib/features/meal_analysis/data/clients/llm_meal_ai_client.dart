import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../../../core/llm/model_identified_llm_client.dart';
import '../../domain/models/meal_ai_invalid_response.dart';
import '../../domain/models/meal_ai_result.dart';
import '../../domain/models/meal_dml_document.dart';
import '../../domain/services/meal_ai_client.dart';
import '../prompts/meal_ai_prompt.dart';

class LlmMealAiClient implements MealAiClient {
  final LocalLlmClient transport;
  final String _modelId;
  @override
  String get modelId => transport is ModelIdentifiedLlmClient
      ? (transport as ModelIdentifiedLlmClient).modelId
      : _modelId;
  final Duration timeout;
  const LlmMealAiClient({
    required this.transport,
    required this._modelId,
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
    var requestPrompt = prompt;
    final deadline = DateTime.now().add(timeout);
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final remaining = deadline.difference(DateTime.now());
        final response = await transport
            .generate(
              LocalLlmRequest(prompt: requestPrompt, timeout: remaining),
            )
            .timeout(remaining);
        try {
          MealAiResult.parse(
            response.text,
            language: language,
            evidenceIds: document.evidenceIds,
            evidenceText: document.text,
          );
          return (prompt: requestPrompt, text: response.text);
        } on FormatException catch (error) {
          if (attempt == 1) throw MealAiInvalidResponse(response.text);
          requestPrompt =
              '$prompt\n'
              'Your previous response failed validation: ${error.message}.\n'
              'Generate a replacement JSON from the original evidence. Use at most ONE finding per section.\n'
              'Copy evidence_refs exactly from the allowed list; never use array indices or invent paths.\n'
              'Check every field, reference and length before returning JSON.\n';
        }
      } on LlmOutputLimitException catch (error) {
        throw MealAiInvalidResponse(error.response, tokenLimitReached: true);
      }
    }
    throw StateError('Structured meal analysis attempts exhausted');
  }
}
