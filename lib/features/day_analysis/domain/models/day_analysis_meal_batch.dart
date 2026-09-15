import 'day_analysis_meal.dart';

class DayAnalysisMealBatch {
  final List<DayAnalysisMeal> meals;
  final Set<int> failedIds;
  DayAnalysisMealBatch({
    required List<DayAnalysisMeal> meals,
    Set<int> failedIds = const {},
  }) : meals = List.unmodifiable(meals),
       failedIds = Set.unmodifiable(failedIds);
}
