import '../../../../core/domain/model/meal_macro_summary.dart';
import 'meal_composition.dart';

class MealAiFacts {
  final int mealId;
  final String name;
  final DateTime eatenAt;
  final DateTime? endedAt;
  final Duration? wait;
  final Duration window;
  final String macroSource;
  final MealMacroSummary? macros;
  final MealComposition? composition;
  final List<({String name, double grams})> ingredients;
  final List<({String status, DateTime at})> stages;
  MealAiFacts({
    required this.mealId,
    required this.name,
    required this.eatenAt,
    required this.endedAt,
    required this.wait,
    required this.window,
    required this.macroSource,
    required this.macros,
    required this.composition,
    required List<({String name, double grams})> ingredients,
    required List<({String status, DateTime at})> stages,
  }) : ingredients = List.unmodifiable(ingredients),
       stages = List.unmodifiable(stages);
}
