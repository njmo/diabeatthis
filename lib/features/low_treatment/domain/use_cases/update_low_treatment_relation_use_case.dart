import 'package:drift/drift.dart';
import '../../../../common/models/timeline_relation.dart';
import '../../../../core/drift/database_impl.dart';

class UpdateLowTreatmentRelationUseCase {
  const UpdateLowTreatmentRelationUseCase(this.db);
  final DatabaseImpl db;

  Future<void> call(
    int mealId,
    TimelineRelation? relation,
  ) => db.transaction(() async {
    final meal = await db.mealDao.getMealById(mealId);
    if (meal == null ||
        meal.purpose != 'lowTreatment' ||
        meal.status != 'confirmed') {
      throw StateError('A confirmed low treatment is required');
    }
    final relatedMealId = relation?.kind == TimelineRelationKind.meal
        ? relation!.id
        : null;
    final activityLogId = relation?.kind == TimelineRelationKind.activity
        ? relation!.id
        : null;
    if (relatedMealId != null) {
      final related = await db.mealDao.getMealById(relatedMealId);
      if (relatedMealId == mealId ||
          related == null ||
          related.purpose != 'meal') {
        throw StateError('A related meal is required');
      }
    }
    if (activityLogId != null &&
        await db.activityDao.getActivityLogByIdOrNull(activityLogId) == null) {
      throw StateError('Related activity does not exist');
    }
    final existing = await db.lowTreatmentContextDao.getContextForMeal(mealId);
    if (existing == null) {
      await db.lowTreatmentContextDao.upsertContextForMeal(
        LowTreatmentContextCompanion.insert(
          mealId: Value(mealId),
          source: 'manual',
          reason: const Value('manual'),
          relatedMealId: Value(relatedMealId),
          relatedActivityLogId: Value(activityLogId),
        ),
      );
    } else {
      await (db.update(
        db.lowTreatmentContext,
      )..where((row) => row.mealId.equals(mealId))).write(
        LowTreatmentContextCompanion(
          relatedMealId: Value(relatedMealId),
          relatedActivityLogId: Value(activityLogId),
          isSynced: const Value(false),
        ),
      );
    }
  });
}
