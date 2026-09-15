import '../models/day_dml_document.dart';

/// Transport-independent port: implement with an on-device or remote model.
abstract interface class DayAnalysisClient {
  String get modelId;
  Future<String> analyze(DayDmlDocument document, {required String language});
}
