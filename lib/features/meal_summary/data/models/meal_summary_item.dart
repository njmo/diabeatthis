import 'meal_summary_portion.dart';

class MealSummaryItem {
  final int id;
  final String name;
  final MealSummaryPortion? portion;
  final bool isReference;

  final double plannedAmount;
  final double reportedAmount;
  final double consumedAmount;
  final double consumedConfidence;
  final double netCarbsPerAmount;
  final double? gramsPerAmount;
  final bool isExtra;
  final double? carbsPerAmount;
  final double fatPerAmount;
  final double proteinPerAmount;
  final double fiberPerAmount;

  MealSummaryItem({
    required this.id,
    required this.name,
    required this.portion,
    required this.isReference,
    required this.plannedAmount,
    required this.reportedAmount,
    required this.consumedAmount,
    required this.consumedConfidence,
    required this.netCarbsPerAmount,
    this.gramsPerAmount,
    this.isExtra = false,
    this.carbsPerAmount,
    this.fatPerAmount = 0,
    this.proteinPerAmount = 0,
    this.fiberPerAmount = 0,
  });
}
