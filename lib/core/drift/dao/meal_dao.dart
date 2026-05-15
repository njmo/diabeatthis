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

  Future<List<MealData>> getRecentMealsPage({int page = 0, int pageSize = 10}) {
    final query = select(db.meal)
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(pageSize, offset: page * pageSize);
    return query.get();
  }

  Future<List<MealData>> searchMealsPageByName({
    required String queryString,
    int page = 0,
    int pageSize = 10,
  }) {
    final normalizedQuery = queryString.trim().toLowerCase();
    final query = select(db.meal)
      ..where((tbl) => tbl.name.like('%$normalizedQuery%'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(pageSize, offset: page * pageSize);
    return query.get();
  }

  Future<List<MealData>> getMealsPageByIngredientIds({
    required List<int> ingredientIds,
    int page = 0,
    int pageSize = 10,
  }) async {
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    if (distinctIngredientIds.isEmpty) {
      return getRecentMealsPage(page: page, pageSize: pageSize);
    }

    final mealIngredientMealId = db.mealIngredients.mealId;
    final mealIngredientIngredientId = db.mealIngredients.ingredientId;
    final distinctIngredientCount = mealIngredientIngredientId.count(
      distinct: true,
    );

    final mealIdRows =
        await (selectOnly(db.mealIngredients)
              ..addColumns([mealIngredientMealId])
              ..where(mealIngredientIngredientId.isIn(distinctIngredientIds))
              ..groupBy(
                [mealIngredientMealId],
                having: distinctIngredientCount.equals(
                  distinctIngredientIds.length,
                ),
              ))
            .get();
    final mealIds = mealIdRows
        .map((row) => row.read(mealIngredientMealId))
        .whereType<int>()
        .toList(growable: false);
    if (mealIds.isEmpty) {
      return const [];
    }

    final query = select(db.meal)
      ..where((tbl) => tbl.id.isIn(mealIds))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(pageSize, offset: page * pageSize);
    return query.get();
  }

  Future<List<MealData>> searchMealsByName(String queryString) {
    final query = select(db.meal)
      ..where((tbl) => tbl.name.like('%$queryString%'))
      ..orderBy([(m) => OrderingTerm(expression: m.updatedAt)])
      ..limit(10);

    return query.get();
  }
}
