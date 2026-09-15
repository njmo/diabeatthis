import '../../../../core/domain/model/meal_macro_summary.dart';

/// Recorded meal facts, distinct from an advisor recommendation or insulin delivery.
class DayAnalysisMeal {
  final int id;
  final String name;
  final DateTime eatenAt;
  final DateTime? eatingEndedAt;
  final Duration? wait;
  final Duration window;
  final MealMacroSummary? macros;
  final String macroSource;
  final List<({String name, double grams})> ingredients;
  final List<({String status, DateTime at})> stages;

  DayAnalysisMeal({
    required this.id,
    required this.name,
    required this.eatenAt,
    required this.eatingEndedAt,
    required this.wait,
    required this.window,
    required this.macros,
    required this.macroSource,
    required List<({String name, double grams})> ingredients,
    required List<({String status, DateTime at})> stages,
  }) : ingredients = List.unmodifiable(ingredients),
       stages = List.unmodifiable(stages);
}
