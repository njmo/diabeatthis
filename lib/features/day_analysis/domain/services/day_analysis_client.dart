import '../models/day_analysis_response.dart';
import '../models/day_dml_document.dart';

/// Transport-independent port: implement with an on-device or remote model.
abstract interface class DayAnalysisClient {
  String get modelId;
  Future<DayAnalysisResponse> analyze(
    DayDmlDocument document, {
    required String language,
  });
}
