import '../../../../core/domain/model/bolus_wizard.dart';
import '../../data/models/meal_advice_history_comparison.dart';
import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';

class SelectMealCalculatorsUseCase {
  const SelectMealCalculatorsUseCase();
  List<BolusWizard> call(MealDetailsData details, MealAnalysisData analysis) =>
      available(
        analysis,
      ).where((wizard) => isAssigned(details, wizard)).toList();

  List<BolusWizard> available(MealAnalysisData analysis) =>
      MealAdviceHistoryComparison(analysis).wizards;

  bool isAssigned(MealDetailsData details, BolusWizard wizard) =>
      details.wizardAssignments?.any(
        (link) =>
            !link.dismissed &&
            link.mealId == details.meal.id &&
            link.matches(wizard),
      ) ==
      true;
}
