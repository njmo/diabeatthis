import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';
import '../models/meal_application_review.dart';
import 'build_meal_portion_use_case.dart';
import 'select_meal_calculators_use_case.dart';

class BuildMealApplicationReviewUseCase {
  const BuildMealApplicationReviewUseCase();

  MealApplicationReview call(
    MealDetailsData details,
    MealAnalysisData? analysis,
  ) {
    final decision = details.advisorDecision;
    final wizards = analysis == null
        ? null
        : const SelectMealCalculatorsUseCase()(details, analysis);
    final carbs = wizards?.length == 1
        ? wizards!.single.calculatorResult?.carbs
        : null;
    final consumed = details.consumedSnapshot?.totalNetCarbsG;
    final consumedCarbs = consumed != null && consumed.isFinite && consumed >= 0
        ? consumed
        : null;
    final calculatorCarbs = carbs != null && carbs.isFinite && carbs >= 0
        ? carbs
        : null;
    return MealApplicationReview(
      proposedWait:
          decision == null || decision.isManual || decision.initialWaitTime <= 0
          ? null
          : Duration(minutes: decision.initialWaitTime),
      actualWait: details.recordedWait,
      consumedCarbs: consumedCarbs,
      calculatorCarbs: calculatorCarbs,
      carbsMatch: consumedCarbs == null || calculatorCarbs == null
          ? null
          : mealPortionAmountsMatch(consumedCarbs, calculatorCarbs),
      calculatorCount: wizards?.length ?? 0,
      manual: decision?.isManual == true,
    );
  }
}
