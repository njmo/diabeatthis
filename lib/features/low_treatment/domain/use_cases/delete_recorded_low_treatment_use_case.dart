import '../../../../core/drift/database_impl.dart';

class DeleteRecordedLowTreatmentUseCase {
  const DeleteRecordedLowTreatmentUseCase(this.db);

  final DatabaseImpl db;

  Future<void> call(int mealId) => db.transaction(() async {
    final meal = await db.mealDao.getMealById(mealId);
    if (meal == null ||
        meal.purpose != 'lowTreatment' ||
        meal.status != 'confirmed') {
      throw StateError('A confirmed low treatment is required');
    }
    await db.mealDao.deleteMealAndGeneratedData(mealId);
  });
}
