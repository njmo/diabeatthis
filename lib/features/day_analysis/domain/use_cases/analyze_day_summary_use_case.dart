import '../../../../core/logger/logger.dart';
import '../models/day_analysis_draft.dart';
import '../models/day_analysis_invalid_response.dart';
import '../models/day_analysis_result.dart';
import '../models/day_dml_document.dart';
import '../services/day_analysis_client.dart';

class AnalyzeDaySummaryUseCase with Logging {
  final DayAnalysisClient client;
  final DateTime Function() now;
  final int promptVersion;

  const AnalyzeDaySummaryUseCase({
    required this.client,
    required this.now,
    required this.promptVersion,
  });

  Future<DayAnalysisDraft> call(
    DayDmlDocument document, {
    required String language,
  }) async {
    if (language != 'pl' && language != 'en') {
      throw ArgumentError.value(language, 'language');
    }
    logI(
      'Requesting day analysis: model=${client.modelId}, language=$language',
    );
    final generated = await client.analyze(document, language: language);
    final response = generated.text;
    logI('Validating day analysis: responseCharacters=${response.length}');
    final DayAnalysisResult result;
    try {
      result = DayAnalysisResult.parse(
        response,
        language: language,
        evidenceIds: document.evidenceIds,
        mealSectionIds: document.meals.keys.toList(),
      );
    } on FormatException catch (error) {
      // JSON decoder errors can contain response fragments. Never log those.
      final reason = error.source == null
          ? error.message
          : 'Invalid JSON at offset ${error.offset}';
      logW('Day analysis validation failed: $reason');
      throw DayAnalysisInvalidResponse(response: response, reason: reason);
    }
    logI('Day analysis prepared');
    return DayAnalysisDraft(
      document: document,
      prompt: generated.prompt,
      rawResponse: response,
      result: result,
      modelId: client.modelId,
      generatedAt: now(),
      promptVersion: promptVersion,
    );
  }
}
