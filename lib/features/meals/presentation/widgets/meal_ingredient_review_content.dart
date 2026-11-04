import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../common/nutrition/ingredient_confidence.dart';
import '../../../../common/widgets/confidence_indicator.dart';
import '../../../../common/widgets/confidence_slider.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';
import '../../../ingredients/data/icons/ingredient_icon_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'meal_ingredient_review_header.dart';
import 'meal_ingredient_review_nutrition.dart';

class MealIngredientReviewContent extends ConsumerWidget {
  const MealIngredientReviewContent({
    super.key,
    required this.draft,
    required this.gramsPerPortion,
    this.isLoadingPortionAmount = false,
  });

  final MealIngredientsDraft draft;
  final double? gramsPerPortion;
  final bool isLoadingPortionAmount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final totalGrams = calculateIngredientTotalGrams(
      amount: draft.amount,
      kind: draft.amountKind,
      gramsPerPortion: gramsPerPortion,
    );
    final combinedConfidence = combineIngredientConfidence(
      nutritionConfidence:
          draft.nutritionConfidenceOverride ??
          draft.ingredient.nutritionConfidence,
      quantityConfidence: draft.quantityConfidence,
    );
    final confidenceLevel = ConfidenceLevelX.fromDouble01(combinedConfidence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MealIngredientReviewHeader(
          iconAssetPath:
              draft.ingredient.iconAssetPath ??
              ref
                  .watch(
                    ingredientIconSuggestionProvider((
                      draft.ingredient.name,
                      draft.ingredient.brand,
                    )),
                  )
                  .asData
                  ?.value,
          name: draft.ingredient.name,
          description: draft.measureDescription(
            gramsPerPortion: gramsPerPortion,
            isLoading: isLoadingPortionAmount,
          ),
        ),
        const SizedBox(height: 16),
        NutritionMetricTile(
          icon: draft.ingredient.isReference
              ? Icons.restaurant
              : Icons.scale_outlined,
          label: lang.addIngredientAmountTitle,
          emphasized: false,
          value: draft.ingredient.isReference
              ? '${draft.amount.formattedAmount} × ${unitLabelForAmount(1, draft.portionCountUnitLabel)}'
              : isLoadingPortionAmount
              ? lang.commonLoading
              : totalGrams == null
              ? lang.amountMissingPortionWeight
              : draft.usesGramAmount
              ? '${totalGrams.formattedAmount} g'
              : '${draft.amount.formattedAmount} × ${unitLabelForAmount(1, draft.portionCountUnitLabel)} · ${totalGrams.formattedAmount} g',
        ),
        const SizedBox(height: 16),
        MealIngredientReviewNutrition(
          ingredient: draft.ingredient,
          totalGrams: isLoadingPortionAmount ? null : totalGrams,
        ),
        const SizedBox(height: 16),
        ConfidenceIndicator(
          value: combinedConfidence,
          title: lang.ingredientCombinedConfidence,
          levelLabel: lang.ingredientConfidenceScore(
            confidenceLevel.label,
            (combinedConfidence * 100).round(),
          ),
        ),
      ],
    );
  }
}
