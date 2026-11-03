/// Whole grams shared by the AAPS instruction, receipt matching and new uploads.
/// Nutrition snapshots retain their original precision.
double lowTreatmentDeliveryCarbs(double carbs) {
  if (!carbs.isFinite || carbs <= 0) {
    throw ArgumentError.value(
      carbs,
      'carbs',
      'Positive carbohydrates required',
    );
  }
  final rounded = carbs.roundToDouble();
  if (rounded <= 0) {
    throw ArgumentError.value(
      carbs,
      'carbs',
      'Carbohydrates round to zero grams',
    );
  }
  return rounded;
}
