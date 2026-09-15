import '../../../../core/llm/llm_output_limit_exception.dart';
import '../../../../core/llm/local_llm_client.dart';
import '../../domain/models/day_analysis_invalid_response.dart';
import '../../domain/models/day_dml_document.dart';
import '../../domain/services/day_analysis_client.dart';
import '../prompts/day_analysis_prompt.dart';

/// Reuses the existing text transport; no Firebase or local-engine API leaks out.
class LlmDayAnalysisClient implements DayAnalysisClient {
  final LocalLlmClient transport;
  @override
  final String modelId;
  final Duration timeout;

  const LlmDayAnalysisClient({
    required this.transport,
    required this.modelId,
    this.timeout = const Duration(seconds: 60),
  });

  @override
  Future<String> analyze(
    DayDmlDocument document, {
    required String language,
  }) async {
    if (language != 'pl' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    try {
      final response = await transport
          .generate(
            LocalLlmRequest(
              prompt: buildDayAnalysisPrompt(document, language),
              timeout: timeout,
            ),
          )
          .timeout(timeout);
      return response.text;
    } on LlmOutputLimitException catch (error) {
      throw DayAnalysisInvalidResponse(
        response: error.response,
        reason: 'Model output token limit reached',
        tokenLimitReached: true,
      );
    }
  }
}
