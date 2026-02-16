import 'package:drift/drift.dart';
import '../../../features/dashboard/data/utils/meal_advisor.dart';
import '../database_impl.dart';

part 'meal_advisor_result_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal_advisor_result.drift'})
class MealAdvisorResultDao extends DatabaseAccessor<DatabaseImpl> with _$MealAdvisorResultDaoMixin {
  MealAdvisorResultDao(super.db);

  Future<MealAdvisorResultData?> getMealAdvisorResult(int mealId) async {
    final query = select(db.mealAdvisorResult)..where((tbl) => tbl.mealId.equals(mealId));
    return query.getSingleOrNull();
  }

  Future<int> insertMealAdvisorResult(int mealId, MealAdvice advice)
  {
    final adviceResult = MealAdvisorResultCompanion(
      mealId: Value(mealId),
      result: Value(advice.decision!.status),
      acceptedWaitTime: Value(advice.wait?.recommendedMinutes ?? 0),
      suggestedWaitTime: Value(advice.wait?.recommendedMinutes ?? 0),
      waitTimeIgnored: Value(advice.wait == null),
    );
    return into(db.mealAdvisorResult).insert(adviceResult);
  }
}