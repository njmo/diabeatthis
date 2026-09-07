import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/drafts/meal_draft.dart';
import '../utils/meal_ingredient_portion_formatters.dart';

class CopiedMealIngredientRow extends StatelessWidget {
  const CopiedMealIngredientRow({super.key, required this.item});

  final MealIngredientsDraft item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.ingredient.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  item.ingredient.isReference
                      ? context.lang.ingredientReferenceBadge
                      : item.portionDescription(
                          portionAmount: item.ingredientPortion.amount,
                          isLoading: false,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.amount.formattedAmount} ${unitLabelForAmount(item.amount, item.portionCountUnitLabel)}',
                textAlign: TextAlign.end,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
