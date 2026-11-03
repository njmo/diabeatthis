import '../../domain/models/before_meal_context.dart';
import '../../domain/models/before_meal_overview_review.dart';
import '../../domain/use_cases/select_recorded_carbs_suggestion_use_case.dart';
import 'meal_target_preparation_controller.dart';

class BeforeMealOverviewController {
  const BeforeMealOverviewController({
    this.targets = const MealTargetPreparationController(),
    this.suggestions = const SelectRecordedCarbsSuggestionUseCase(),
  });
  final MealTargetPreparationController targets;
  final SelectRecordedCarbsSuggestionUseCase suggestions;

  BeforeMealOverviewReview build(
    BeforeMealContext data, {
    required bool hasRecordedStart,
  }) => BeforeMealOverviewReview(
    preparation: targets.build(
      treatments: data.treatments,
      recordedMealStart: hasRecordedStart ? data.asOf : null,
    ),
    carbsSuggestion: suggestions(data.latestDeviceStatus, data.asOf),
  );
}
