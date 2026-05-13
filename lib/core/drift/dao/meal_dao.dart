import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'meal_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal.drift'})
class MealDao extends DatabaseAccessor<DatabaseImpl> with _$MealDaoMixin {
  MealDao(super.db);

  Future<void> updateMealStatus(int id, String status) async {
    await (update(db.meal)..where((t) => t.id.equals(id))).write(
      MealCompanion(status: Value(status)),
    );
  }

  Stream<List<MealData>> getAllMealForToday() {
    final now = clock.now().toUtc();
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

  Future<void> deleteMealAndGeneratedData(int id) async {
    await transaction(() async {
      await (delete(
        db.mealAdvisorResult,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealSnapshot,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealIngredients,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealStatusHistory,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (update(db.meal)..where((tbl) => tbl.basedOnMealId.equals(id)))
          .write(const MealCompanion(basedOnMealId: Value(null)));
      await (delete(db.meal)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<List<MealData>> getMealsBetween(
    DateTime start,
    DateTime end, {
    int? excludeMealId,
  }) {
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.plannedAt)]);
    if (excludeMealId != null) {
      query.where((tbl) => tbl.id.equals(excludeMealId).not());
    }
    return query.get();
  }

  Future<List<MealData>> getMealsForIngredient(int ingredientId) {
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(meal.id),
            ),
          ])
          ..where(db.mealIngredients.ingredientId.equals(ingredientId))
          ..limit(10);

    return query.map((row) => row.readTable(db.meal)).get();
  }

  Future<MealData?> getNearestMeal() async {
    final now = clock.now().toUtc();
    final todayMillisecondsSinceEpoch = now.millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch),
      )
      ..where((tbl) => tbl.status.equals('planned'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.asc),
      ])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Stream<MealData?> getNearestMealStream() async* {
    Stream<void> mealChangeTrigger() {
      return (select(db.meal)..limit(1)).watch().map((_) {});
    }

    while (true) {
      final current = await getNearestMeal();
      yield current;

      if (current == null) {
        await mealChangeTrigger().first;
        continue;
      }

      final waitDuration = DateTime.fromMillisecondsSinceEpoch(
        current.plannedAt,
      ).difference(clock.now().toUtc());

      if (waitDuration <= Duration.zero) {
        continue;
      }

      try {
        await mealChangeTrigger().timeout(waitDuration).first;
      } on TimeoutException {
        continue;
      }
    }
  }

  Stream<List<MealData>> getAllPlannedMealForToday() {
    final now = clock.now().toUtc();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch),
      )
      ..where((tbl) => tbl.status.equals('skipped').not())
      ..where((tbl) => tbl.status.equals('summarized').not())
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Stream<List<MealData>> getAllMeals({int page = 0}) {
    final query = select(db.meal)
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(10, offset: page * 10);
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
