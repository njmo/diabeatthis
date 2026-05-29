import 'package:drift/drift.dart';

import '../../domain/model/low_treatment_context.dart' as domain;
import '../database_impl.dart';
import '../mappers/low_treatment_context_drift_mapper.dart';

part 'low_treatment_context_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/low_treatment_context.drift'})
class LowTreatmentContextDao extends DatabaseAccessor<DatabaseImpl>
    with _$LowTreatmentContextDaoMixin {
  LowTreatmentContextDao(super.db);

  Future<domain.LowTreatmentContext?> getContextForMeal(int mealId) async {
    final query = select(db.lowTreatmentContext)
      ..where((tbl) => tbl.mealId.equals(mealId));
    final row = await query.getSingleOrNull();
    return row?.toDomain();
  }

  Future<List<domain.LowTreatmentContext>> getContextsForRelatedMeal(
    int relatedMealId,
  ) async {
    final query = select(db.lowTreatmentContext)
      ..where((tbl) => tbl.relatedMealId.equals(relatedMealId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => row.toDomain()).toList(growable: false);
  }

  Future<List<domain.LowTreatmentContext>> getContextsForRelatedActivityLog(
    int activityLogId,
  ) async {
    final query = select(db.lowTreatmentContext)
      ..where((tbl) => tbl.relatedActivityLogId.equals(activityLogId))
      ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)]);
    final rows = await query.get();
    return rows.map((row) => row.toDomain()).toList(growable: false);
  }

  Future<domain.LowTreatmentContext> upsertContextForMeal(
    LowTreatmentContextCompanion context,
  ) async {
    final row = await into(
      db.lowTreatmentContext,
    ).insertReturning(context, onConflict: DoUpdate((_) => context));
    return row.toDomain();
  }
}
