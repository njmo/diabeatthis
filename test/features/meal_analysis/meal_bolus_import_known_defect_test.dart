import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'an isolated Nightscout meal bolus with insulin and carbs contributes delivered insulin to the meal outcome',
    () {
      final mealAt = DateTime.utc(2026, 9, 1, 12);
      final bolusAt = mealAt.add(const Duration(minutes: 5));
      final end = mealAt.add(const Duration(minutes: 30));
      final treatments = TreatmentFactory().parseTreatments([
        <String, dynamic>{
          '_id': 'meal-bolus-1',
          'eventType': 'Meal Bolus',
          'created_at': bolusAt.toIso8601String(),
          'insulin': 2.0,
          'carbs': 15,
          'isValid': true,
        },
      ]);
      final result = const BuildMealOutcomeContextUseCase()(
        mealTime: mealAt,
        window: const Duration(minutes: 30),
        asOf: end,
        builtAt: end,
        treatmentHistoryStart: mealAt.subtract(const Duration(hours: 24)),
        glucose: [],
        deviceStatuses: [],
        treatments: treatments,
        lowTreatments: [],
        activities: [],
        subsequentMeals: [],
      );
      expect(result.boluses.units, 2);
    },
  );
}
