import 'day_analysis_result.dart';
import 'day_dml_document.dart';

/// Generated preview only; creating this object never accepts or persists it.
class DayAnalysisDraft {
  final DayDmlDocument document;
  final DayAnalysisResult result;
  final String modelId;
  final String rawResponse;
  final DateTime generatedAt;
  final int promptVersion;

  /// Null only for archives created before exact prompts were retained.
  final String? prompt;

  const DayAnalysisDraft({
    required this.document,
    this.prompt,
    required this.result,
    required this.modelId,
    required this.rawResponse,
    required this.generatedAt,
    required this.promptVersion,
  });
}
