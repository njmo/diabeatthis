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

  Future<MealData> createLowTreatmentEntry({
    required String name,
    required DateTime eatenAt,
    String? notes,
  }) {
    return into(db.meal).insertReturning(
      MealCompanion.insert(
        name: name,
        plannedAt: eatenAt.millisecondsSinceEpoch,
        summarizedAt: Value(eatenAt.millisecondsSinceEpoch),
        purpose: const Value('lowTreatment'),
        status: const Value('confirmed'),
        notes: Value(notes),
      ),
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
      ..where((tbl) => tbl.purpose.equals('meal'))
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
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.plannedAt)]);
    if (excludeMealId != null) {
      query.where((tbl) => tbl.id.equals(excludeMealId).not());
    }
    return query.get();
  }

  Future<MealData?> getLatestMealBefore(
    DateTime before, {
    required Duration maxAge,
  }) {
    final start = before.subtract(maxAge);
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          before.millisecondsSinceEpoch,
        ),
      )
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where(
        (tbl) => tbl.status.isIn([
          'eaten',
          'eaten-extra',
          'eaten-bolused',
          'summarized',
        ]),
      )
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);

    return query.getSingleOrNull();
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
      ..where((tbl) => tbl.purpose.equals('meal'))
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
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.status.equals('skipped').not())
      ..where((tbl) => tbl.status.equals('summarized').not())
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Stream<List<MealData>> getAllMeals({int page = 0}) {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(10, offset: page * 10);
    return query.watch();
  }

  Stream<List<MealData>> watchRecentMeals({required int limit}) {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<MealData>> watchMealsByName({
    required String queryString,
    required int limit,
  }) {
    final normalizedQuery = queryString.trim().toLowerCase();
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.name.like('%$normalizedQuery%'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<MealData>> watchMealsByIngredientIds({
    required List<int> ingredientIds,
    required int limit,
  }) {
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    if (distinctIngredientIds.isEmpty) {
      return watchRecentMeals(limit: limit);
    }

    final distinctIngredientCount = db.mealIngredients.ingredientId.count(
      distinct: true,
    );
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(db.meal.id),
            ),
          ])
          ..where(db.meal.purpose.equals('meal'))
          ..where(db.mealIngredients.ingredientId.isIn(distinctIngredientIds))
          ..groupBy(
            [db.meal.id],
            having: distinctIngredientCount.equals(
              distinctIngredientIds.length,
            ),
          )
          ..orderBy([
            OrderingTerm(
              expression: db.meal.plannedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.meal)).toList(),
    );
  }

  Future<List<MealData>> getMealsBasedOnMeal(int mealId) {
    final query = select(db.meal)
      ..where((tbl) => tbl.basedOnMealId.equals(mealId))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  Future<MealData?> getLatestMealForCopySource({
    int? baseMealId,
    int? mealTemplateId,
  }) async {
    if (baseMealId == null && mealTemplateId == null) {
      return null;
    }

    final query = select(db.meal)
      ..where((tbl) {
        Expression<bool>? condition;
        if (baseMealId != null) {
          condition =
              tbl.id.equals(baseMealId) | tbl.basedOnMealId.equals(baseMealId);
        }
        if (mealTemplateId != null) {
          final templateCondition = tbl.mealTemplateId.equals(mealTemplateId);
          condition = condition == null
              ? templateCondition
              : condition | templateCondition;
        }
        return condition ?? const Constant(false);
      })
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<List<MealData>> searchMealsByName(String queryString) {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.name.like('%$queryString%'))
      ..orderBy([(m) => OrderingTerm(expression: m.updatedAt)])
      ..limit(10);

    return query.get();
  }
}
