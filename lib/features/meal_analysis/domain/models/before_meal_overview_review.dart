import 'meal_target_preparation.dart';
import 'recorded_carbs_suggestion.dart';

class BeforeMealOverviewReview {
  const BeforeMealOverviewReview({
    required this.preparation,
    required this.carbsSuggestion,
  });
  final MealTargetPreparation? preparation;
  final RecordedCarbsSuggestion? carbsSuggestion;
}
