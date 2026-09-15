import 'dart:convert';

import '../../../../core/drift/database_impl.dart';
import '../../domain/models/accepted_day_analysis.dart';
import '../../domain/models/day_analysis_draft.dart';
import '../../domain/models/day_analysis_result.dart';
import '../../domain/models/day_dml_document.dart';

class DayAiRepository {
  final DatabaseImpl db;
  const DayAiRepository(this.db);

  Future<AcceptedDayAnalysis?> get(String dayKey) async {
    final row = await (db.select(
      db.acceptedDayAi,
    )..where((row) => row.dayKey.equals(dayKey))).getSingleOrNull();
    if (row == null) return null;
    final data = jsonDecode(row.payload) as Map<String, dynamic>;
    if (data['version'] != 1 || data['dmlVersion'] != DayDmlDocument.version) {
      throw const FormatException('Unsupported saved day analysis');
    }
    final document = DayDmlDocument(
      text: data['dml'] as String,
      evidenceIds: (data['evidenceIds'] as List).cast<String>().toSet(),
      meals: (data['meals'] as Map<String, dynamic>).map(
        (id, meal) => MapEntry(id, (
          name: meal['name'] as String,
          at: DateTime.parse(meal['at'] as String).toLocal(),
        )),
      ),
    );
    return AcceptedDayAnalysis(
      acceptedAt: DateTime.fromMillisecondsSinceEpoch(row.acceptedAt),
      analysis: DayAnalysisDraft(
        document: document,
        prompt: data['prompt'] as String?,
        result: DayAnalysisResult.parse(
          data['result'] as String,
          language: data['language'] as String,
          evidenceIds: document.evidenceIds,
          mealSectionIds: document.meals.keys.toList(),
        ),
        modelId: data['modelId'] as String,
        rawResponse: data['rawResponse'] as String,
        generatedAt: DateTime.parse(data['generatedAt'] as String).toLocal(),
        promptVersion: data['promptVersion'] as int,
      ),
    );
  }

  Future<void> save(String dayKey, AcceptedDayAnalysis accepted) async {
    final analysis = accepted.analysis;
    await db
        .into(db.acceptedDayAi)
        .insertOnConflictUpdate(
          AcceptedDayAiCompanion.insert(
            dayKey: dayKey,
            acceptedAt: accepted.acceptedAt.millisecondsSinceEpoch,
            payload: jsonEncode({
              'version': 1,
              'dmlVersion': DayDmlDocument.version,
              'dml': analysis.document.text,
              'evidenceIds': analysis.document.evidenceIds.toList(),
              'meals': analysis.document.meals.map(
                (id, meal) => MapEntry(id, {
                  'name': meal.name,
                  'at': meal.at.toUtc().toIso8601String(),
                }),
              ),
              'result': analysis.result.encode(),
              'language': analysis.result.language,
              'modelId': analysis.modelId,
              'rawResponse': analysis.rawResponse,
              'generatedAt': analysis.generatedAt.toUtc().toIso8601String(),
              'promptVersion': analysis.promptVersion,
              'prompt': analysis.prompt,
            }),
          ),
        );
  }
}
