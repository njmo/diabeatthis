import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../mappers/meal_details_data_mapper.dart';
import '../../models/meal_details_data.dart';

part 'load_low_treatments_for_meal_use_case.g.dart';

@riverpod
Future<List<MealLowTreatmentDetailsData>> mealLowTreatmentsForMealUseCase(
  Ref ref,
  int mealId,
) {
  return LoadLowTreatmentsForMealUseCase(ref: ref).call(mealId);
}

class LoadLowTreatmentsForMealUseCase {
  const LoadLowTreatmentsForMealUseCase({required this.ref});

  final Ref ref;

  Future<List<MealLowTreatmentDetailsData>> call(int mealId) async {
    final db = ref.read(databaseProvider);
    final mapper = MealDetailsDataMapper(db: db);
    final contexts = await db.lowTreatmentContextDao.getContextsForRelatedMeal(
      mealId,
    );
    final treatments = <MealLowTreatmentDetailsData>[];

    for (final context in contexts) {
      final meal = await db.mealDao.getMealById(context.mealId);
      if (meal == null || meal.purpose != 'lowTreatment') {
        continue;
      }

      final mealIngredients = await db.mealIngredientsDao
          .getMealIngredientsForMeal(meal.id);
      final ingredients = <MealIngredientDetailsData>[];
      for (final mealIngredient in mealIngredients) {
        ingredients.add(
          await mapper.mapIngredient(
            meal: meal,
            mealIngredient: mealIngredient,
            plannedSnapshot: null,
            consumedSnapshot: null,
          ),
        );
      }

      treatments.add(
        MealLowTreatmentDetailsData(
          meal: mapper.mapMeal(meal),
          context: context,
          ingredients: ingredients,
        ),
      );
    }

    treatments.sort((a, b) => a.meal.plannedAt.compareTo(b.meal.plannedAt));
    return treatments;
  }
}
