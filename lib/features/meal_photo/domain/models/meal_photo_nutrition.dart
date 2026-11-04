import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';

/// Values describe one whole reference portion, or 100 g when held by a candidate.
class MealPhotoNutrition {
  const MealPhotoNutrition({
    required this.carbs,
    required this.fiber,
    required this.fat,
    required this.protein,
    required this.carbsLabelMode,
  });
  final double carbs;
  final double fiber;
  final double fat;
  final double protein;
  final CarbsLabelMode carbsLabelMode;
  double get netCarbs =>
      calculateNetCarbs(carbs: carbs, fiber: fiber, labelMode: carbsLabelMode);
  double get kcal => calculateNetKcalPer100g(
    carbsPer100g: carbs,
    fiberPer100g: fiber,
    fatPer100g: fat,
    proteinPer100g: protein,
    labelMode: carbsLabelMode,
  );
  MealPhotoNutrition scaled(double factor) => MealPhotoNutrition(
    carbs: carbs * factor,
    fiber: fiber * factor,
    fat: fat * factor,
    protein: protein * factor,
    carbsLabelMode: carbsLabelMode,
  );
  void validate() {
    if ([carbs, fiber, fat, protein].any((n) => !n.isFinite || n < 0) ||
        (carbsLabelMode == CarbsLabelMode.nonEu && fiber > carbs)) {
      throw const FormatException('Invalid nutrition facts');
    }
  }
}
