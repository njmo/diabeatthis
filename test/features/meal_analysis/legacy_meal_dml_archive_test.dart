import 'package:diabeatthis/core/drift/database_impl.dart' hide AcceptedMealAi;
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_ai_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_dml_document.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart' show aiMealTime, aiResponse;

void main() {
  test(
    'saved DML/1 keeps its original layout, field citations, prompt and response',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Archived',
              plannedAt: aiMealTime.millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      const oldText =
          'DML/1\nmeal_before {"mean_mg_dl":123,"aaps":{"prediction":{"series":{"IOB":[[0,123],[5,120]]}}}}';
      final document = MealDmlDocument(
        mealId: 1,
        text: oldText,
        evidenceIds: {'meal_before'},
      );
      final response = aiResponse(reference: 'meal_before.mean_mg_dl');
      final result = MealAiResult.parse(
        response,
        language: 'pl',
        evidenceIds: document.evidenceIds,
        evidenceText: oldText,
      );
      final archive = MealAiRepository(db);
      await archive.save(
        AcceptedMealAi(
          acceptedAt: aiMealTime,
          draft: MealAiDraft(
            document: document,
            result: result,
            prompt: 'Original prompt',
            rawResponse: response,
            modelId: 'archived-model',
            generatedAt: aiMealTime,
            promptVersion: 1,
          ),
        ),
      );
      final loaded = (await archive.get(1))!;
      expect(loaded.draft.document.text, oldText);
      expect(loaded.draft.prompt, 'Original prompt');
      expect(loaded.draft.rawResponse, response);
      expect(
        loaded.draft.result.sections['response']!.findings.single.evidenceRefs,
        ['meal_before.mean_mg_dl'],
      );
    },
  );
}
