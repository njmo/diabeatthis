import '../../../../common/meal/meal_snapshot_history_reader.dart';
import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/drift/database_impl.dart' hide LowTreatmentContext;
import '../../../meals/data/mappers/meal_details_data_mapper.dart';
import '../../../meals/data/models/meal_details_data.dart';
import 'recorded_low_treatment_repository.dart';

/// One historical interpretation for low treatments linked to meals or activity.
class LinkedLowTreatmentDetailsRepository {
  const LinkedLowTreatmentDetailsRepository(this.db);
  final DatabaseImpl db;

  Future<MealLowTreatmentDetailsData> load(
    MealData meal,
    LowTreatmentContext context,
  ) async {
    final mapper = MealDetailsDataMapper(db: db);
    final snapshots = (await MealSnapshotHistoryReader(
      db,
    ).read(meal.id)).snapshots;
    final planned = snapshots
        .where((row) => row.snapshotType == 'planned')
        .firstOrNull;
    final consumed = snapshots
        .where((row) => row.snapshotType == 'consumed')
        .firstOrNull;
    final entries = await db.mealIngredientsDao.getMealIngredientsForMeal(
      meal.id,
    );
    final ingredients = <MealIngredientDetailsData>[];
    for (final entry in entries) {
      ingredients.add(
        await mapper.mapIngredient(
          meal: meal,
          mealIngredient: entry,
          plannedSnapshot: planned,
          consumedSnapshot: consumed,
        ),
      );
    }
    return MealLowTreatmentDetailsData(
      meal: mapper.mapMeal(meal),
      context: context,
      ingredients: ingredients,
      recorded: await RecordedLowTreatmentRepository(db).fetchByMealId(meal.id),
    );
  }
}
