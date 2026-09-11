import '../../../../core/domain/model/meal_macro_summary.dart';
import 'recorded_meal_context.dart';

/// A macro comparison, not a probability of the same glucose response.
class SimilarMealMatch {
  final RecordedMealContext meal;
  final double distance;
  final bool matchesIngredients;
  final double? portionRatio;
  const SimilarMealMatch({
    required this.meal,
    required this.distance,
    this.matchesIngredients = false,
    this.portionRatio,
  });
}

class SimilarMealContext {
  final DateTime asOf;
  final DateTime searchStart;
  final MealMacroSummary target;
  final List<SimilarMealMatch> matches;

  SimilarMealContext({
    required this.asOf,
    required this.searchStart,
    required this.target,
    required List<SimilarMealMatch> matches,
  }) : matches = List.unmodifiable(matches);
}
