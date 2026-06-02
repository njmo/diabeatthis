import 'carbs_label_mode.dart';

double calculateNetCarbs({
  required double carbs,
  required double fiber,
  required CarbsLabelMode labelMode,
}) {
  return switch (labelMode) {
    CarbsLabelMode.eu => carbs,
    CarbsLabelMode.nonEu => _clampNetCarbs(carbs - fiber),
  };
}

double _clampNetCarbs(double netCarbs) {
  return netCarbs < 0 ? 0 : netCarbs;
}

double calculateNetKcalPer100g({
  required double carbsPer100g,
  required double fiberPer100g,
  required double fatPer100g,
  required double proteinPer100g,
  required CarbsLabelMode labelMode,
}) {
  final netCarbs = calculateNetCarbs(
    carbs: carbsPer100g,
    fiber: fiberPer100g,
    labelMode: labelMode,
  );
  return proteinPer100g * 4 + netCarbs * 4 + fatPer100g * 9;
}
