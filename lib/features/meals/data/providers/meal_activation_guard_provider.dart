import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal.dart' as domain;
import '../../../../core/domain/model/meal_status_flow.dart';
import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';

final anyMealBlockingActivationProvider = StreamProvider<domain.Meal?>((ref) {
  final query = _mealBlockingActivationQuery(ref);
  return query.watchSingleOrNull().map((meal) => meal?.toDomain());
});

final currentMealBlockingActivationProvider =
    FutureProvider.autoDispose<domain.Meal?>((ref) async {
      final query = _mealBlockingActivationQuery(ref);
      final blockingMeal = await query.getSingleOrNull();
      return blockingMeal?.toDomain();
    });

final mealBlockingActivationProvider = FutureProvider.autoDispose
    .family<domain.Meal?, int>((ref, mealId) async {
      final query = _mealBlockingActivationQuery(ref, excludeMealId: mealId);
      final blockingMeal = await query.getSingleOrNull();
      return blockingMeal?.toDomain();
    });

SimpleSelectStatement<Meal, MealData> _mealBlockingActivationQuery(
  Ref ref, {
  int? excludeMealId,
}) {
  final db = ref.watch(databaseProvider);
  final query = db.select(db.meal)
    ..where((tbl) => tbl.purpose.equals(domain.MealPurpose.meal.storageValue))
    ..where(
      (tbl) => tbl.status.isIn(
        mealStatusesBlockingAnotherMealActivation.toList(growable: false),
      ),
    )
    ..orderBy([(tbl) => OrderingTerm.asc(tbl.plannedAt)])
    ..limit(1);

  if (excludeMealId != null) {
    query.where((tbl) => tbl.id.equals(excludeMealId).not());
  }

  return query;
}
