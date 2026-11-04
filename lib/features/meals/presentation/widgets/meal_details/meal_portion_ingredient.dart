import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/ingredient_confidence_summary.dart';
import '../../../data/models/meal_details_data.dart';

class MealPortionIngredient extends StatelessWidget {
  const MealPortionIngredient({
    super.key,
    required this.ingredient,
    required this.hasConsumedSnapshot,
  });
  final MealIngredientDetailsData ingredient;
  final bool hasConsumedSnapshot;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final reported = ingredient.consumedAmount != null;
    final amount = reported
        ? ingredient.consumedTotalGrams
        : ingredient.plannedTotalGrams;
    final increased =
        reported &&
        !ingredient.isExtra &&
        ingredient.consumedTotalGrams > ingredient.plannedTotalGrams + 0.05;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        ingredient.ingredientName,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            !ingredient.recordedWeightAvailable
                ? lang.amountMissingPortionWeight
                : reported
                ? lang.mealConsumedInline('${number.format(amount)} g')
                : lang.mealPlanInline('${number.format(amount)} g'),
          ),
          IngredientConfidenceSummary(
            nutritionConfidence: hasConsumedSnapshot
                ? ingredient.consumedHistoricalNutritionUnavailable
                      ? null
                      : ingredient.consumedNutrition.nutritionConfidence
                : ingredient.plannedHistoricalNutritionUnavailable
                ? null
                : ingredient.plannedNutrition.nutritionConfidence,
            quantityConfidence: hasConsumedSnapshot
                ? ingredient.consumedConfidence
                : ingredient.quantityConfidence,
          ),
          if (hasConsumedSnapshot && !reported)
            Text(lang.mealPortionUnconfirmed),
          if (ingredient.isExtra)
            Text(
              lang.mealExtraBadge,
              style: TextStyle(
                color: colors.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (increased)
            Text(
              lang.mealPortionExtraGrams(
                number.format(
                  ingredient.consumedTotalGrams - ingredient.plannedTotalGrams,
                ),
              ),
              style: TextStyle(
                color: colors.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (reported &&
              !ingredient.isExtra &&
              number.format(ingredient.plannedTotalGrams) !=
                  number.format(ingredient.consumedTotalGrams))
            Text(
              lang.mealPlanInline(
                '${number.format(ingredient.plannedTotalGrams)} g',
              ),
            ),
        ],
      ),
      onTap: () => context.router.push(
        IngredientRoute(ingredientId: ingredient.ingredientId),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
