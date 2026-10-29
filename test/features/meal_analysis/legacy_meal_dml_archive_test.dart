import 'dart:convert';

import 'package:diabeatthis/core/drift/database_impl.dart' hide AcceptedMealAi;
import 'package:diabeatthis/features/day_analysis/data/repositories/day_ai_repository.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_summary_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_analysis.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_draft.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_analysis_result.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_dml_document.dart';
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_ai_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_dml_document.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../day_analysis/day_dml_test.dart' show dmlFixture;
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
  test(
    'saved day input keeps legacy inline forecasts and its accepted summary unchanged',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final accepted = dmlFixture();
      final originalSummary = accepted.snapshot.encode();
      await DaySummaryRepository(db).insert(accepted);
      const oldText =
          'DML/1\nDAY {"id":"day"}\nMEAL {"id":"meal:1","before":{"aaps":{"prediction":{"series":{"IOB":[[0,120],[5,130]]}}}}}';
      final document = DayDmlDocument(
        text: oldText,
        evidenceIds: {'day', 'meal:1'},
      );
      final response = jsonEncode({
        'schema_version': 1,
        'language': 'pl',
        'sections': {
          for (final section in DayAnalysisResult.sectionNames)
            section: {
              'status': 'ok',
              'summary': '',
              'findings': [],
              'missing_data': [],
            },
        },
      });
      final repository = DayAiRepository(db);
      await repository.save(
        accepted.snapshot.dayKey,
        AcceptedDayAnalysis(
          acceptedAt: aiMealTime,
          analysis: DayAnalysisDraft(
            document: document,
            result: DayAnalysisResult.parse(
              response,
              language: 'pl',
              evidenceIds: document.evidenceIds,
            ),
            modelId: 'legacy',
            rawResponse: response,
            generatedAt: aiMealTime,
            promptVersion: 1,
            prompt: 'Original day prompt',
          ),
        ),
      );
      final loaded = (await repository.get(accepted.snapshot.dayKey))!;
      expect(loaded.analysis.document.text, oldText);
      expect(loaded.analysis.prompt, 'Original day prompt');
      expect(loaded.analysis.rawResponse, response);
      expect(
        (await DaySummaryRepository(
          db,
        ).get(accepted.snapshot.dayKey))!.snapshot.encode(),
        originalSummary,
      );
    },
  );
}
