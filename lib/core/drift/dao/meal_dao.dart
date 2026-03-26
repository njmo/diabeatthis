import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal.drift'})
class MealDao extends DatabaseAccessor<DatabaseImpl> with _$MealDaoMixin {
  MealDao(super.db);

  void updateMealStatus(int id, String status) async {
    await (update(db.meal)..where((t) => t.id.equals(id))).write(
      MealCompanion(status: Value(status)),
    );
  }

  Stream<List<MealData>> getAllMealForToday() {
    final now = clock.now();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch),
      )
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Future<MealData?> getMealById(int id) async {
    final query = select(db.meal)..where((tbl) => tbl.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<MealData?> getNearestMeal() async {
    final now = clock.now();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
            (tbl) => tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch),
      )
      ..where((tbl) => tbl.status.equals('planned'))
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.asc)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Stream<MealData> getNearestMealStream() {
    final now = clock.now();
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBiggerThanValue(now.millisecondsSinceEpoch),
      )
      ..where((tbl) => tbl.status.equals('planned'))
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.asc)]);
    return query.watchSingle();
  }

  Stream<List<MealData>> getAllPlannedMealForToday() {
    final now = clock.now();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch),
      )
      ..where((tbl) => tbl.status.contains('eaten').not())
      ..where((tbl) => tbl.status.equals('skipped').not())
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Future<List<MealData>> searchMealsByName(String queryString) {
    final query = select(db.meal)
      ..where((tbl) => tbl.name.like('%$queryString%'))
      ..orderBy([(m) => OrderingTerm(expression: m.updatedAt)])
      ..limit(10);

    return query.get();
  }
}
