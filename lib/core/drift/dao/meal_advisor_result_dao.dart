import 'package:drift/drift.dart';

import '../database_impl.dart';

part 'meal_advisor_result_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_advisor_result.drift'})
class MealAdvisorResultDao extends DatabaseAccessor<DatabaseImpl>
    with _$MealAdvisorResultDaoMixin {
  MealAdvisorResultDao(super.db);

  Future<List<String>> getMealStatusHistory(int mealId) async {
    final rows = await (select(
      db.mealStatusHistory,
    )..where((t) => t.mealId.equals(mealId))).get();
    return rows.map((row) => row.status).toList();
  }

  Future<MealAdvisorResultData?> getMealAdvisorResult(int mealId) async {
    final query = select(db.mealAdvisorResult)
      ..where((tbl) => tbl.mealId.equals(mealId));
    return query.getSingleOrNull();
  }

  Future<void> updateAdvisorResultFinalWaitTime(
    int mealId,
    int finalWaitTime,
  ) async {
    await (update(db.mealAdvisorResult)..where((t) => t.mealId.equals(mealId)))
        .write(MealAdvisorResultCompanion(finalWaitTime: Value(finalWaitTime)));
  }

  Future<int?> getMealAdvisorResultInitialWaitTime(int mealId) async {
    final row = await (select(
      db.mealAdvisorResult,
    )..where((tbl) => tbl.mealId.equals(mealId))).getSingleOrNull();

    return row?.initialWaitTime;
  }

  Future<void> updateAdvisorResultWaitOutcome({
    required int mealId,
    required int finalWaitTime,
    required bool waitTimeIgnored,
  }) async {
    await (update(
      db.mealAdvisorResult,
    )..where((t) => t.mealId.equals(mealId))).write(
      MealAdvisorResultCompanion(
        finalWaitTime: Value(finalWaitTime),
        waitTimeIgnored: Value(waitTimeIgnored),
      ),
    );
  }

  Future<int> insertMealAdvisorResult(MealAdvisorResultCompanion result) {
    return into(db.mealAdvisorResult).insert(result);
  }
}
