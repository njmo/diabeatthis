import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../low_treatment/data/repositories/linked_low_treatment_details_repository.dart';
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
    final repository = LinkedLowTreatmentDetailsRepository(db);
    final contexts = await db.lowTreatmentContextDao
        .getContextsForRelatedActivityLog(activityLogId);
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
