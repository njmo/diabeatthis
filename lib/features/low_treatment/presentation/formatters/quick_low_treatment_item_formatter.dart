import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/quick_low_treatment_item.dart';

String formatQuickLowTreatmentItemDetails(QuickLowTreatmentItem item) {
  final carbs = _calculateQuickLowTreatmentCarbs(item).round();
  final amount = _formatQuickLowTreatmentAmount(item.amount);

  if (item.portion == null) {
    if (item.ingredient.isReference) {
      return lang.quickLowTreatmentReferenceDetails(
        amount,
        carbs,
        _referencePortionLabel(item.amount),
      );
    }
    return lang.quickLowTreatmentGramDetails(amount, carbs);
  }

  return lang.quickLowTreatmentPortionDetails(
    amount,
    carbs,
    item.portion!.name,
  );
}

double _calculateQuickLowTreatmentCarbs(QuickLowTreatmentItem item) {
  final grams = _quickLowTreatmentItemGrams(item);
  return grams * item.ingredient.carbsPer100g / 100;
}

double _quickLowTreatmentItemGrams(QuickLowTreatmentItem item) {
  if (item.portion != null) {
    return item.amount * (item.gramsPerPortion ?? 0);
  }
  if (item.ingredient.isReference) {
    return item.amount * 100;
  }
  return item.amount;
}

String _formatQuickLowTreatmentAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

String _referencePortionLabel(double amount) {
  if (amount == 1) {
    return 'porcja';
  }
  if (amount == amount.roundToDouble() && amount >= 2 && amount <= 4) {
    return 'porcje';
  }
  return 'porcji';
}
