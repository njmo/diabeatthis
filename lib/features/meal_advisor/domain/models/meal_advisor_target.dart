import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../meal_analysis/domain/models/meal_composition.dart';
import '../../../meal_analysis/domain/models/meal_record_evidence.dart';

/// A planned meal at decision time; it deliberately has no eating or outcome time.
class MealAdvisorTarget {
  final int mealId;
  final String name;
  final DateTime plannedAt;
  final MealMacroSummary macros;
  final MealComposition? composition;
  final MealNutritionConfidence? confidence;
  final List<({String name, double grams})> ingredients;
  MealAdvisorTarget({
    required this.mealId,
    required this.name,
    required this.plannedAt,
    required this.macros,
    required this.composition,
    required this.confidence,
    required List<({String name, double grams})> ingredients,
  }) : ingredients = List.unmodifiable(ingredients);
}
