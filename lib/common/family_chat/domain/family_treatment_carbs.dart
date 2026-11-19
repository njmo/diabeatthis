import '../../meal/low_treatment_delivery_carbs.dart';

/// Shared wire contract: six decimal places, positive half-up rounding.
/// Nutrition and the existing whole-gram delivery record are distinct values.
double familyTreatmentNutritionCarbs(double value) {
  if (!value.isFinite || value <= 0 || value > 10000) {
    throw ArgumentError('Invalid treatment carbohydrates');
  }
  return (value * 1000000 + .5).floorToDouble() / 1000000;
}

int familyTreatmentRecordedCarbs(double nutrition) {
  final value = familyTreatmentNutritionCarbs(nutrition);
  if (value < .5) {
    throw ArgumentError('Treatment rounds below one recorded gram');
  }
  return lowTreatmentDeliveryCarbs(value).toInt();
}
