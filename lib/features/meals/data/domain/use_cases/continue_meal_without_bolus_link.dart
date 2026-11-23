import '../../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../../common/meal/meal_decision.dart';
import '../../../../../core/drift/database_impl.dart';
import '../../../../dashboard/data/repositories/meal_advisor_result_store.dart';
import '../../../../dashboard/data/use_cases/meal_advisor_result_use_case.dart';

/// Records the user's confirmation in the meal workflow. The actual treatment
/// remains available for review and linking in the day summary.
Future<bool> continueMealWithoutBolusLink(DatabaseImpl db, int mealId) =>
    db.transaction(() async {
      final meal = await db.mealDao.getMealById(mealId);
      if (meal == null ||
          meal.purpose != 'meal' ||
          meal.status != 'waiting-for-bolus' ||
          MealAddOnBolusContext.decode(meal.addOnBolusContext)?.awaitingBolus ==
              true) {
        return false;
      }
      final advice = await MealAdvisorResultUseCase(
        DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
      ).loadMealAdvice(mealId);
      final next = switch (advice?.decision) {
        MealDecision.bolusAndEatNow => 'bolused-eating',
        MealDecision.bolusWaitThenEat => 'bolused-waiting',
        MealDecision.eatNowBolusLater || null => 'eaten-bolused',
        MealDecision.bolus => null,
      };
      return next != null && await db.mealDao.tryUpdateMealStatus(mealId, next);
    });
