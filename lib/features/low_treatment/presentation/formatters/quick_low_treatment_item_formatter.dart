import '../../../../core/domain/model/quick_low_treatment_item.dart';

String formatQuickLowTreatmentItemDetails(QuickLowTreatmentItem item) {
  final carbs = _calculateQuickLowTreatmentCarbs(item).round();
  final amount = _formatQuickLowTreatmentAmount(item.amount);

  if (item.portion == null) {
    return '$amount g • $carbs g WW';
  }

  return '$amount x ${item.portion!.name} • $carbs g WW';
}

double _calculateQuickLowTreatmentCarbs(QuickLowTreatmentItem item) {
  final grams = item.portion == null
      ? item.amount
      : item.amount * (item.gramsPerPortion ?? 0);
  return grams * item.ingredient.carbsPer100g / 100;
}

String _formatQuickLowTreatmentAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
