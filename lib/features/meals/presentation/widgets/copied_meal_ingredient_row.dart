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
                if (item.ingredient.isReference) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.lang.ingredientReferenceBadge,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              '${item.amount.formattedAmount} ${unitLabelForAmount(item.amount, item.portionCountUnitLabel)}',
              textAlign: TextAlign.end,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}
