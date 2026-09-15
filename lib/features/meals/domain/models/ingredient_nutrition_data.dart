import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';

class IngredientNutritionData {
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final double proteinPer100g;
  final CarbsLabelMode carbsLabelMode;
  final double nutritionConfidence;
  final DateTime? effectiveAt;

  const IngredientNutritionData({
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
    required this.proteinPer100g,
    required this.carbsLabelMode,
    required this.nutritionConfidence,
    required this.effectiveAt,
  });

  double get kcalPer100g {
    return proteinPer100g * 4 + carbsPer100g * 4 + fatPer100g * 9;
  }

  double get wbtKcalPer100g {
    return proteinPer100g * 4 + fatPer100g * 9;
  }

  double get safeNetCarbsPer100g {
    return calculateNetCarbs(
      carbs: carbsPer100g,
      fiber: fiberPer100g,
      labelMode: carbsLabelMode,
    );
  }

  bool differsFrom(IngredientNutritionData other) {
    return carbsPer100g != other.carbsPer100g ||
        fatPer100g != other.fatPer100g ||
        fiberPer100g != other.fiberPer100g ||
        proteinPer100g != other.proteinPer100g ||
        carbsLabelMode != other.carbsLabelMode ||
        nutritionConfidence != other.nutritionConfidence;
  }
}
