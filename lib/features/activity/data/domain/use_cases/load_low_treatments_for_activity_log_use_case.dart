import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../meals/data/mappers/meal_details_data_mapper.dart';
import '../../../../meals/data/models/meal_details_data.dart';

part 'load_low_treatments_for_activity_log_use_case.g.dart';

@riverpod
Future<List<MealLowTreatmentDetailsData>> activityLogLowTreatmentsUseCase(
  Ref ref,
  int activityLogId,
) {
  final db = ref.watch(databaseProvider);
  return LoadLowTreatmentsForActivityLogUseCase(db: db).call(activityLogId);
}

class LoadLowTreatmentsForActivityLogUseCase {
  const LoadLowTreatmentsForActivityLogUseCase({required this.db});

  final DatabaseImpl db;

  Future<List<MealLowTreatmentDetailsData>> call(int activityLogId) async {
    final mapper = MealDetailsDataMapper(db: db);
    final contexts = await db.lowTreatmentContextDao
        .getContextsForRelatedActivityLog(activityLogId);
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
