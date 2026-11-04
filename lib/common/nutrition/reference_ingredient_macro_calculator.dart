const defaultReferenceFatShare = 0.5;

const _fatKcalPerGram = 9.0;
const _proteinKcalPerGram = 4.0;
const _extendedCarbsKcalRatio = 10.0;

double referenceFatPer100g({
  required double extendedCarbsPer100g,
  required double fatShare,
}) {
  return _extendedCarbsKcal(extendedCarbsPer100g) *
      _safeShare(fatShare) /
      _fatKcalPerGram;
}

double referenceProteinPer100g({
  required double extendedCarbsPer100g,
  required double fatShare,
}) {
  return _extendedCarbsKcal(extendedCarbsPer100g) *
      (1 - _safeShare(fatShare)) /
      _proteinKcalPerGram;
}

double referenceExtendedCarbsPer100g({
  required double fatPer100g,
  required double proteinPer100g,
}) {
  final kcalFromFat = _nonNegative(fatPer100g) * _fatKcalPerGram;
  final kcalFromProtein = _nonNegative(proteinPer100g) * _proteinKcalPerGram;

  return (kcalFromFat + kcalFromProtein) / _extendedCarbsKcalRatio;
}

double referenceFatShare({
  required double fatPer100g,
  required double proteinPer100g,
}) {
  final kcalFromFat = _nonNegative(fatPer100g) * _fatKcalPerGram;
  final kcalFromProtein = _nonNegative(proteinPer100g) * _proteinKcalPerGram;
  final totalKcal = kcalFromFat + kcalFromProtein;

  if (totalKcal <= 0) {
    return defaultReferenceFatShare;
  }

  return kcalFromFat / totalKcal;
}

double parseReferenceMacroInput(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0;
}

String formatReferenceMacroInput(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2);
}

double _extendedCarbsKcal(double extendedCarbsPer100g) {
  return _nonNegative(extendedCarbsPer100g) * _extendedCarbsKcalRatio;
}

double _safeShare(double value) {
  return value.clamp(0.0, 1.0);
}

double _nonNegative(double value) => value < 0 ? 0 : value;
