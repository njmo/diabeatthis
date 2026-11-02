import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../../data/models/meal_details_data.dart';
import '../../../domain/use_cases/build_meal_portion_use_case.dart';
import '../../controllers/meal_portion_controller.dart';
import 'meal_macro_comparison.dart';
import 'meal_portion_ingredient.dart';
import 'meal_portion_macros.dart';

class MealPortionOverview extends StatelessWidget {
  const MealPortionOverview({super.key, required this.details});
  final MealDetailsData details;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.#', lang.localeName);
    final summary = const MealPortionController().build(details);
    final planned = summary.planned;
    final consumed = summary.consumed;
    final nutrition = summary.nutrition;
    final equal = summary.equal;
    final status = switch (summary.status) {
      MealPortionStatus.planned => lang.mealReviewPlanned,
      MealPortionStatus.unconfirmed => lang.mealPortionUnconfirmed,
      MealPortionStatus.asPlanned => lang.mealPortionAsPlanned,
      MealPortionStatus.consumed => lang.mealReviewConsumed,
    };
    return SummaryDetailCard(
      title: lang.mealPortionCardTitle,
      icon: Icons.restaurant_rounded,
      headerColor: Theme.of(context).colorScheme.tertiaryContainer,
      headerForeground: Theme.of(context).colorScheme.onTertiaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(status, style: Theme.of(context).textTheme.titleSmall),
          if (consumed == null && details.meal.isEaten && planned != null)
            Text(lang.mealPortionPlanOnly),
          if (details.ingredients.isEmpty) Text(lang.mealNoIngredientsTitle),
          for (final ingredient in summary.ingredients)
            MealPortionIngredient(
              ingredient: ingredient,
              hasConsumedSnapshot: consumed != null,
            ),
          if (summary.extras.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              lang.mealPortionExtraIngredients,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
            for (final ingredient in summary.extras)
              MealPortionIngredient(
                ingredient: ingredient,
                hasConsumedSnapshot: consumed != null,
              ),
          ],
          if (nutrition != null) ...[
            const Divider(height: 28),
            if (planned != null && consumed != null && !equal)
              MealMacroComparison(planned: planned, consumed: consumed)
            else
              MealPortionMacros(nutrition: nutrition),
            const SizedBox(height: 12),
            Text(
              '${lang.mealTotalMassLabel}: ${number.format(nutrition.totalGrams)} g',
            ),
            if (planned != null &&
                consumed != null &&
                number.format(planned.totalGrams) !=
                    number.format(consumed.totalGrams))
              Text(
                lang.mealPlanInline('${number.format(planned.totalGrams)} g'),
              ),
          ],
        ],
      ),
    );
  }
}
