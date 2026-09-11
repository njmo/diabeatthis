import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/domain/model/meal_snapshot.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

final referenceTime = DateTime(2026, 9, 10, 12);
final targetMacros = MealMacroSummary(
  carbsGrams: 30,
  netCarbsGrams: 30,
  proteinGrams: 15,
  fatGrams: 10,
  fiberGrams: 0,
  totalGrams: 150,
);

RecordedMealContext candidate(
  int id, {
  double scale = 1,
  double carbs = 30,
  double protein = 15,
  double fat = 10,
  DateTime? at,
  MealSnapshotType type = MealSnapshotType.consumed,
}) => RecordedMealContext(
  mealId: id,
  name: 'Meal $id',
  eatenAt: at ?? referenceTime.subtract(Duration(days: id)),
  snapshot: MealSnapshot(
    mealId: id,
    snapshotType: type,
    totalGrams: 150 * scale,
    totalCarbsG: carbs * scale,
    totalFiberG: 0,
    totalNetCarbsG: carbs * scale,
    totalProteinG: protein * scale,
    totalFatG: fat * scale,
    totalCaloriesKcal: 270 * scale,
    ingredientsCount: 3,
    avgQuantityConfidence: null,
    minQuantityConfidence: null,
    carbWeightedQuantityConfidence: null,
    wbtWeightedQuantityConfidence: null,
    carbWeightedNutritionConfidence: null,
    wbtWeightedNutritionConfidence: null,
    carbWeightedEffectiveConfidence: null,
    wbtWeightedEffectiveConfidence: null,
  ),
);

void main() {
  test('ranks by size and composition, not name or energy alone', () async {
    final useCase = FindSimilarMealsUseCase(
      loadMeals: (start, end, excluded) async {
        expect(start, referenceTime.subtract(const Duration(days: 90)));
        expect(end, referenceTime);
        expect(excluded, 100);
        return [
          candidate(1, scale: 2),
          candidate(2, scale: 1.1),
          candidate(3),
          candidate(4, carbs: 67.5, protein: 0, fat: 0),
        ];
      },
    );
    final result = await useCase(
      mealId: 100,
      asOf: referenceTime,
      target: targetMacros,
    );
    expect(result.matches.map((m) => m.meal.mealId), [3, 2]);
    expect(result.matches.first.distance, 0);
    expect(() => result.matches.clear(), throwsUnsupportedError);
  });

  test(
    'excludes future, current, too old, incomplete and missing snapshots',
    () async {
      final result = await FindSimilarMealsUseCase(
        loadMeals: (_, _, _) async => [
          candidate(100),
          candidate(2, at: referenceTime),
          candidate(3, at: referenceTime.subtract(const Duration(days: 91))),
          candidate(4, at: referenceTime.subtract(const Duration(hours: 2))),
          RecordedMealContext(
            mealId: 5,
            name: 'Missing',
            eatenAt: referenceTime.subtract(const Duration(days: 1)),
            snapshot: null,
          ),
          candidate(6, at: referenceTime.subtract(const Duration(hours: 3))),
        ],
      )(mealId: 100, asOf: referenceTime, target: targetMacros);
      expect(result.matches.single.meal.mealId, 6);
    },
  );

  test(
    'preserves planned provenance, deduplicates and limits to eight',
    () async {
      final result = await FindSimilarMealsUseCase(
        loadMeals: (_, _, _) async => [
          for (var id = 5; id <= 12; id++) candidate(id),
          candidate(3),
          candidate(2),
          candidate(1, type: MealSnapshotType.planned),
          candidate(1),
        ],
      )(mealId: 100, asOf: referenceTime, target: targetMacros);
      expect(result.matches.map((m) => m.meal.mealId), [
        1,
        2,
        3,
        5,
        6,
        7,
        8,
        9,
      ]);
      expect(
        result.matches.first.meal.snapshot!.snapshotType,
        MealSnapshotType.planned,
      );
    },
  );

  test(
    'invalid target avoids I/O and invalid candidates are excluded',
    () async {
      var calls = 0;
      final useCase = FindSimilarMealsUseCase(
        loadMeals: (_, _, _) async {
          calls++;
          return [
            candidate(1, carbs: double.nan),
            candidate(2, fat: -1),
            candidate(3, scale: 0),
          ];
        },
      );
      final empty = MealMacroSummary(
        carbsGrams: 0,
        fatGrams: 0,
        proteinGrams: 0,
        fiberGrams: 0,
        totalGrams: 0,
      );
      expect(
        (await useCase(
          mealId: 100,
          asOf: referenceTime,
          target: empty,
        )).matches,
        isEmpty,
      );
      expect(calls, 0);
      expect(
        (await useCase(
          mealId: 100,
          asOf: referenceTime,
          target: targetMacros,
        )).matches,
        isEmpty,
      );
    },
  );

  test(
    'source failure remains an error rather than an empty match list',
    () async {
      final useCase = FindSimilarMealsUseCase(
        loadMeals: (_, _, _) async => throw StateError('offline'),
      );
      await expectLater(
        useCase(mealId: 100, asOf: referenceTime, target: targetMacros),
        throwsStateError,
      );
    },
  );
}
