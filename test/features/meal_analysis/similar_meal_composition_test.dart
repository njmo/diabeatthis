import 'package:diabeatthis/features/meal_analysis/domain/models/meal_composition.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'find_similar_meals_use_case_test.dart'
    show candidate, referenceTime, targetMacros;

void main() {
  test(
    'same ingredients at double portion rank before an exact macro match',
    () async {
      final larger = candidate(2, scale: 2);
      final result =
          await FindSimilarMealsUseCase(
            loadMeals: (_, _, _) async => [
              candidate(1),
              RecordedMealContext(
                mealId: larger.mealId,
                name: larger.name,
                eatenAt: larger.eatenAt,
                snapshot: larger.snapshot,
                composition: MealComposition({1: 200, 2: 100}),
              ),
            ],
          )(
            mealId: 100,
            asOf: referenceTime,
            target: targetMacros,
            composition: MealComposition({1: 100, 2: 50}),
          );
      expect(result.matches.map((m) => m.meal.mealId), [2, 1]);
      expect(result.matches.first.matchesIngredients, true);
      expect(result.matches.first.portionRatio, 2);
      expect(result.matches.last.matchesIngredients, false);
    },
  );
  test(
    'different ingredients and changed proportions do not match composition',
    () {
      final original = MealComposition({1: 100, 2: 100});
      expect(original.distanceTo(MealComposition({3: 100, 4: 100})), 1);
      expect(
        original.distanceTo(MealComposition({1: 190, 2: 10})),
        greaterThan(.2),
      );
      expect(original.distanceTo(MealComposition({1: 0})), isNull);
      expect(original.distanceTo(MealComposition({})), isNull);
      expect(original.distanceTo(MealComposition({1: 200, 2: 200})), 0);
    },
  );
}
