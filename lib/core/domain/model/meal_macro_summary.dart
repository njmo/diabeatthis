double _calculateKcal(double netCarbs, double fat, double protein) {
  return netCarbs * 4 + fat * 9 + protein * 4;
}

class MealMacroSummary {
  final double carbsGrams;
  final double fatGrams;
  final double proteinGrams;
  final double fiberGrams;
  final double totalGrams;
  final double netCarbsGrams;
  final double totalKcal;

  MealMacroSummary({
    required this.carbsGrams,
    required this.fatGrams,
    required this.proteinGrams,
    required this.fiberGrams,
    required this.totalGrams,
    double? netCarbsGrams,
  }) : netCarbsGrams = netCarbsGrams ?? (carbsGrams < 0 ? 0 : carbsGrams),
       totalKcal = _calculateKcal(
         netCarbsGrams ?? (carbsGrams < 0 ? 0 : carbsGrams),
         fatGrams,
         proteinGrams,
       );
}
