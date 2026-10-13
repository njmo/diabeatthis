import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/drift/database_impl.dart' hide AcceptedMealAi;
import '../../domain/models/meal_ai_draft.dart';
import '../../domain/models/meal_ai_result.dart';
import '../../domain/models/meal_dml_document.dart';

class MealAiRepository {
  final DatabaseImpl db;
  const MealAiRepository(this.db);
  Future<AcceptedMealAi?> get(int mealId) async {
    final row = await (db.select(
      db.acceptedMealAi,
    )..where((r) => r.mealId.equals(mealId))).getSingleOrNull();
    if (row == null) return null;
    final data = jsonDecode(row.payload) as Map<String, dynamic>;
    if (data['version'] != 1 ||
        data['dmlVersion'] != MealDmlDocument.version ||
        data['mealId'] != mealId) {
      throw const FormatException('Unsupported saved meal analysis');
    }
    final document = MealDmlDocument(
      mealId: mealId,
      text: data['dml'] as String,
      evidenceIds: (data['evidenceIds'] as List).cast<String>().toSet(),
    );
    return AcceptedMealAi(
      acceptedAt: DateTime.fromMillisecondsSinceEpoch(row.acceptedAt),
      draft: MealAiDraft(
        document: document,
        result: MealAiResult.parse(
          data['result'] as String,
          language: data['language'] as String,
          evidenceIds: document.evidenceIds,
        ),
        prompt: data['prompt'] as String,
        rawResponse: data['rawResponse'] as String,
        modelId: data['modelId'] as String,
        generatedAt: DateTime.parse(data['generatedAt'] as String).toLocal(),
        promptVersion: data['promptVersion'] as int,
      ),
    );
  }

  Future<void> save(AcceptedMealAi accepted) => db.transaction(() async {
    final draft = accepted.draft;
    final meal = await db.mealDao.getMealById(draft.document.mealId);
    if (meal == null ||
        !{
          'eaten',
          'eaten-extra',
          'eaten-bolused',
          'summarized',
        }.contains(meal.status) ||
        meal.purpose == 'lowTreatment') {
      throw StateError('An eaten meal is required');
    }
    await db
        .into(db.acceptedMealAi)
        .insertOnConflictUpdate(
          AcceptedMealAiCompanion.insert(
            mealId: Value(draft.document.mealId),
            acceptedAt: accepted.acceptedAt.millisecondsSinceEpoch,
            payload: jsonEncode({
              'version': 1,
              'dmlVersion': MealDmlDocument.version,
              'mealId': draft.document.mealId,
              'dml': draft.document.text,
              'evidenceIds': draft.document.evidenceIds.toList(),
              'result': draft.result.encode(),
              'language': draft.result.language,
              'prompt': draft.prompt,
              'rawResponse': draft.rawResponse,
              'modelId': draft.modelId,
              'promptVersion': draft.promptVersion,
              'generatedAt': draft.generatedAt.toUtc().toIso8601String(),
            }),
          ),
        );
  });
}
