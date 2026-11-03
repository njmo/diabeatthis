import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/show_detail_sheet.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_nutrition_analysis_section.dart';

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
      leading: Icon(
        ingredient.isExtra || increased
            ? Icons.add_circle_outline
            : Icons.restaurant_rounded,
        color: ingredient.isExtra || increased
            ? colors.tertiary
            : colors.primary,
      ),
      title: Text(
        ingredient.ingredientName,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reported
                ? lang.mealConsumedInline('${number.format(amount)} g')
                : lang.mealPlanInline('${number.format(amount)} g'),
          ),
          if (ingredient.quantityConfidence.isFinite &&
              ingredient.quantityConfidence >= 0 &&
              ingredient.quantityConfidence < 1)
            Text(
              lang.mealSavedQuantityEstimate(
                number.format(ingredient.quantityConfidence * 100),
              ),
              style: Theme.of(context).textTheme.bodySmall,
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
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showDetailSheet(
        context: context,
        title: ingredient.ingredientName,
        builder: (_) => MealIngredientTile(
          ingredient: ingredient,
          usePlannedConsumptionFallback: false,
        ),
      ),
    );
  }
}
