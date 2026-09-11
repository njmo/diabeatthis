import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../meals/common/models/meal_wizard_assignment.dart';
import 'day_recorded_meal.dart';

class DayMealReviewEntry {
  final DayRecordedMeal? meal;
  final bool automaticMatchingBlocked;
  final List<BolusWizard> wizards;
  final List<MealWizardAssignment> assignments;

  DayMealReviewEntry({
    required this.meal,
    this.automaticMatchingBlocked = false,
    required List<BolusWizard> wizards,
    required List<MealWizardAssignment> assignments,
  }) : wizards = List.unmodifiable(wizards),
       assignments = List.unmodifiable(assignments);

  DateTime get occurredAt => meal?.eatenAt ?? wizards.first.createdAt;
}
