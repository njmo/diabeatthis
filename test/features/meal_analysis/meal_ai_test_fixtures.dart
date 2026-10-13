import 'dart:convert';

import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_facts.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_dml_document.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_dml_serializer.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';

final aiMealTime = DateTime(2026, 9, 10, 23, 50);
Future<MealAiObservation> aiObservation({
  int id = 1,
  DateTime? time,
  int elapsed = 90,
  List<Treatment> treatments = const [],
}) async {
  final at = time ?? aiMealTime;
  Glucose glucose(int min, int value) => Glucose(
    externalId: 'private-id',
    source: GlucoseSource.cloud,
    date: at.add(Duration(minutes: min)),
    sgv: value,
    direction: 'Flat',
  );
  final before = await BuildBeforeMealContextUseCase(
    loadGlucose: (_, _) async => [glucose(-5, 120)],
    loadDeviceStatuses: (_, _) async => [],
    loadTreatments: (_, _) async => treatments,
    loadMeals: (_, _, _) async => [],
    loadLowTreatments: (_, _) async => [],
    loadActivities: (_, _, _) async => [],
    loadPodAge: (_) async => null,
    now: () => at,
  )(asOf: at, mealId: id, macros: null);
  final outcome = const BuildMealOutcomeContextUseCase()(
    mealTime: at,
    window: const Duration(minutes: 90),
    asOf: at.add(Duration(minutes: elapsed)),
    builtAt: at.add(Duration(minutes: elapsed)),
    treatmentHistoryStart: at.subtract(const Duration(hours: 24)),
    glucose: [glucose(0, 120), glucose(15, 165), glucose(25, 200)],
    deviceStatuses: [],
    treatments: treatments,
    lowTreatments: [],
    activities: [],
    subsequentMeals: [],
    mealId: id,
  );
  return MealAiObservation(
    meal: MealAiFacts(
      mealId: id,
      name: 'Breakfast',
      eatenAt: at,
      endedAt: at.add(const Duration(minutes: 10)),
      wait: const Duration(minutes: 5),
      window: const Duration(minutes: 90),
      macroSource: 'consumed',
      macros: MealMacroSummary(
        carbsGrams: 30,
        proteinGrams: 5,
        fatGrams: 4,
        fiberGrams: 2,
        totalGrams: 100,
      ),
      composition: null,
      ingredients: [(name: 'Bread', grams: 30)],
      stages: [(status: 'eating', at: at)],
    ),
    before: before,
    outcome: outcome,
  );
}

Future<MealDmlDocument> aiDocument() async => serializeMealDml(
  MealAiContext(
    current: await aiObservation(),
    builtAt: aiMealTime.add(const Duration(days: 1)),
    comparisons: [],
    failures: {},
  ),
);
String aiResponse({
  String language = 'pl',
  String reference = 'meal_outcome',
}) => jsonEncode({
  'schema_version': 1,
  'language': language,
  'sections': {
    for (final name in MealAiResult.sectionNames)
      name: {
        'status': 'ok',
        'summary': '',
        'findings': name == 'response'
            ? [
                {
                  'title': 'Rise',
                  'text': 'Glucose rose after the meal.',
                  'kind': 'observation',
                  'confidence': 'medium',
                  'evidence_refs': [reference],
                },
              ]
            : [],
        'missing_data': [],
      },
  },
});

class FixtureMealAiInputController extends MealAiInputController {
  final MealDmlDocument document;
  FixtureMealAiInputController(super.mealId, this.document);
  @override
  Future<MealDmlDocument> build() async => document;
}
