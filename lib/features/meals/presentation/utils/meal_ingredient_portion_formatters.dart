import '../../../../common/l10n/language.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/drafts/meal_draft.dart';

extension MealIngredientPortionPresentationX on MealIngredientsDraft {
  bool get usesGramAmount => ingredientPortion.portion.map(
    empty: (_) => !ingredient.isReference,
    draft: (_) => false,
    existing: (_) => false,
  );

  bool get shouldLoadStoredPortionAmount =>
      ingredientPortion.amount <= 0 &&
      ingredientPortion.portion.maybeMap(
        existing: (_) => true,
        orElse: () => false,
      );

  String get portionCountUnitLabel => ingredientPortion.portion.map(
    empty: (_) => ingredient.isReference ? 'porcja' : 'g',
    draft: (portion) => portion.name,
    existing: (portion) => portion.name,
  );

  String get portionWeightUnitLabel => ingredientPortion.portion.map(
    empty: (_) => 'g',
    draft: (portion) =>
        portion.unitHint.trim().isEmpty ? 'g' : portion.unitHint,
    existing: (portion) =>
        portion.unitHint.trim().isEmpty ? 'g' : portion.unitHint,
  );

  String portionDescription({
    required double? portionAmount,
    required bool isLoading,
  }) {
    final unitLabel = portionCountUnitLabel;
    final weightUnitLabel = portionWeightUnitLabel;
    final amount = portionAmount ?? ingredientPortion.amount;
    final amountLabel = amount > 0 ? amount.formattedAmount : null;

    return ingredientPortion.portion.map(
      empty: (_) => ingredient.isReference
          ? lang.mealReferencePortionDescription
          : lang.addIngredientAddedInGrams,
      draft: (_) {
        if (amountLabel == null) {
          return lang.amountMissingPortionWeight;
        }
        return '1 ${unitLabelForAmount(1, unitLabel)} to $amountLabel $weightUnitLabel';
      },
      existing: (_) {
        if (isLoading) {
          return lang.amountLoadingPortionWeight;
        }
        if (amountLabel == null) {
          return lang.amountMissingPortionWeight;
        }
        return '1 ${unitLabelForAmount(1, unitLabel)} to $amountLabel $weightUnitLabel';
      },
    );
  }
}

extension MealIngredientAmountDoublePresentationX on double {
  String get formattedAmount {
    if (this == roundToDouble()) {
      return toStringAsFixed(0);
    }
    return toStringAsFixed(1).replaceAll('.', ',');
  }
}

String unitLabelForAmount(double amount, String unitLabel) {
  final normalized = unitLabel.trim().toLowerCase();
  if (normalized == 'porcja') {
    if (amount == 1) {
      return 'porcja';
    }
    if (amount == amount.roundToDouble() && amount >= 2 && amount <= 4) {
      return 'porcje';
    }
    return 'porcji';
  }
  if (normalized == 'sztuka') {
    return amount == 1 ? 'sztuka' : 'sztuki';
  }
  return normalized.isEmpty ? 'porcji' : normalized;
}
