import '../models/meal_dml_document.dart';

abstract interface class MealAiClient {
  String get modelId;
  Future<({String prompt, String text})> analyze(
    MealDmlDocument document, {
    required String language,
  });
}
