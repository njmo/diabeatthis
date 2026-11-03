import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../low_treatment/data/repositories/linked_low_treatment_details_repository.dart';
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
    final repository = LinkedLowTreatmentDetailsRepository(db);
    final contexts = await db.lowTreatmentContextDao.getContextsForRelatedMeal(
      mealId,
    );
    final treatments = <MealLowTreatmentDetailsData>[];

    for (final context in contexts) {
      final meal = await db.mealDao.getMealById(context.mealId);
      if (meal == null || meal.purpose != 'lowTreatment') {
        continue;
      }

      treatments.add(await repository.load(meal, context));
    }

    treatments.sort((a, b) => a.meal.plannedAt.compareTo(b.meal.plannedAt));
    return treatments;
  }
}
