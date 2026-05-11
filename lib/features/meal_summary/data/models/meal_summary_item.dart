import 'meal_summary_portion.dart';

class MealSummaryItem {
  final int id;
  final String name;
  final MealSummaryPortion? portion;
  final bool isReference;

  final double plannedAmount;
  final double netCarbsPerAmount;

  MealSummaryItem({
    required this.id,
    required this.name,
    required this.portion,
    required this.isReference,
    required this.plannedAmount,
    required this.netCarbsPerAmount,
  });
}
