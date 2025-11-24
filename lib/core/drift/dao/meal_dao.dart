import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal.drift'})
class MealDao extends DatabaseAccessor<DatabaseImpl> with _$MealDaoMixin {
  MealDao(super.db);

void updateMealStatus(int id, String status) async {
    await (update(db.meal)..where((t) => t.id.equals(id)))
        .write(MealCompanion(status: Value(status)));
  }


  Stream<List<MealData>> getAllMealForToday()
  {
    final now = DateTime.now();
    final query = select(db.meal)
      ..where((tbl) => tbl.plannedAt.isBiggerThanValue(DateTime(now.year, now.month, now.day , 0, 0, 0).millisecondsSinceEpoch))
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }
}