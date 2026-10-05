import '../../../../core/domain/model/meal_macro_summary.dart';
import 'meal_composition.dart';

/// Domain input for a similar-meal search, independent of presentation data.
class SimilarMealQuery {
  final int mealId;
  final DateTime asOf;
  final MealMacroSummary target;
  final MealComposition? composition;

  const SimilarMealQuery({
    required this.mealId,
    required this.asOf,
    required this.target,
    this.composition,
  });
}
