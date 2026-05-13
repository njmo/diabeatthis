import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/utils/meal_extended_carbs_warning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldShowMissingExtendedCarbsWarning', () {
    test(
      'shows warning when WBT is over 100 kcal and extended carbs are missing',
      () {
        final details = _details(snapshot: _snapshot(fatG: 12, proteinG: 0));

        final result = shouldShowMissingExtendedCarbsWarning(
          details: details,
          analysis: _analysis(),
        );

        expect(result, isTrue);
      },
    );

    test('does not show warning when extended carbs are present', () {
      final details = _details(snapshot: _snapshot(fatG: 12, proteinG: 0));

      final result = shouldShowMissingExtendedCarbsWarning(
        details: details,
        analysis: _analysis(
          treatments: [
            ExtendedCarb(
              id: 1,
              createdAt: DateTime(2026, 5, 13, 12, 45),
              carbs: 12,
              duration: 120,
            ),
          ],
        ),
      );

      expect(result, isFalse);
    });

    test('does not show warning at exactly 100 kcal WBT', () {
      final details = _details(snapshot: _snapshot(fatG: 0, proteinG: 25));

      final result = shouldShowMissingExtendedCarbsWarning(
        details: details,
        analysis: _analysis(),
      );

      expect(result, isFalse);
    });
  });
}

MealDetailsData _details({required MealSnapshotDetailsData snapshot}) {
  final now = DateTime(2026, 5, 13, 12);

  return MealDetailsData(
    meal: MealRecordData(
      id: 1,
      name: 'Test',
      status: 'summarized',
      plannedAt: now,
      summarizedAt: now,
      mealTemplateId: null,
      basedOnMealId: null,
      notes: null,
      createdAt: now,
      updatedAt: now,
      isSynced: false,
    ),
    advisorDecision: null,
    ingredients: const [],
    plannedSnapshot: null,
    consumedSnapshot: snapshot,
    statusHistory: const [],
  );
}

MealSnapshotDetailsData _snapshot({
  required double fatG,
  required double proteinG,
}) {
  final now = DateTime(2026, 5, 13, 12);

  return MealSnapshotDetailsData(
    id: 1,
    mealId: 1,
    snapshotType: 'consumed',
    totalGrams: 100,
    totalCarbsG: 0,
    totalFiberG: 0,
    totalNetCarbsG: 0,
    totalFatG: fatG,
    totalProteinG: proteinG,
    totalCaloriesKcal: fatG * 9 + proteinG * 4,
    ingredientsCount: 1,
    avgQuantityConfidence: null,
    minQuantityConfidence: null,
    carbWeightedQuantityConfidence: null,
    wbtWeightedQuantityConfidence: null,
    carbWeightedNutritionConfidence: null,
    wbtWeightedNutritionConfidence: null,
    carbWeightedEffectiveConfidence: null,
    wbtWeightedEffectiveConfidence: null,
    createdAt: now,
    updatedAt: now,
    isSynced: false,
  );
}

MealAnalysisData _analysis({List<Treatment> treatments = const []}) {
  final now = DateTime(2026, 5, 13, 12);

  return MealAnalysisData(
    chartStart: now,
    chartEnd: now,
    expectedChartEnd: now,
    eventStart: now,
    eventEnd: now,
    mealTime: now,
    glucoseReadings: const [],
    treatments: treatments,
    temporaryTargets: const [],
    deviceStatuses: const [],
    linkedActivities: const [],
    linkedMeals: const [],
    timelineEvents: const [],
  );
}
