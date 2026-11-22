import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/model/meal_status_flow.dart';
import '../../core/drift/database_impl.dart';
import '../../core/drift/providers/database_provider.dart';

Future<void> recordMealTreatmentSurplus(DatabaseImpl db, int mealId) async {
  await (db.update(db.meal)..where(
        (row) => row.id.equals(mealId) & row.treatmentSurplus.equals(false),
      ))
      .write(const MealCompanion(treatmentSurplus: Value(true)));
}

final mealTreatmentSurplusesProvider = StreamProvider.autoDispose<Set<int>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final query = db.selectOnly(db.meal)..addColumns([db.meal.id]);
  query.where(
    db.meal.treatmentSurplus.equals(true) &
        db.meal.status.isIn(mealStatusesBlockingAnotherMealActivation),
  );
  return query.watch().map(
    (rows) => rows.map((row) => row.read(db.meal.id)!).toSet(),
  );
});
