import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/nutrition/confidence_level.dart';
import '../../../../../common/nutrition/ingredient_confidence.dart';
import '../../../../../common/nutrition/weighted_confidence.dart';
import '../../../../../common/widgets/confidence_indicator.dart';
import '../../../../../common/widgets/confidence_slider.dart';
import '../../../data/models/meal_details_data.dart';

class MealPortionConfidence extends StatelessWidget {
  const MealPortionConfidence({super.key, required this.details});

  final MealDetailsData details;

  @override
  Widget build(BuildContext context) {
    final consumed = details.consumedSnapshot != null;
    final items = details.ingredients.where(
      (item) => consumed || !item.isExtra,
    );
    final value = weightedConfidence(
      items.map((item) {
        final nutrition = consumed
            ? item.consumedNutrition
            : item.plannedNutrition;
        final quantity = consumed
            ? item.consumedConfidence
            : item.quantityConfidence;
        final unavailable =
            !item.recordedWeightAvailable ||
            (consumed
                ? item.consumedHistoricalNutritionUnavailable
                : item.plannedHistoricalNutritionUnavailable);
        return (
          weight: !item.recordedWeightAvailable
              ? double.nan
              : consumed
              ? item.consumedTotalGrams
              : item.plannedTotalGrams,
          confidence: unavailable || quantity == null
              ? null
              : combineIngredientConfidence(
                  nutritionConfidence: nutrition.nutritionConfidence,
                  quantityConfidence: quantity,
                ),
        );
      }),
    );
    final lang = context.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (value != null)
          ConfidenceIndicator(
            value: value,
            title: lang.mealWeightedConfidenceTitle,
            levelLabel: ConfidenceLevelX.fromDouble01(value).label,
          )
        else
          Text(lang.mealWeightedConfidenceUnavailable),
        const SizedBox(height: 8),
        Text(
          lang.mealWeightedConfidenceExplanation,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
