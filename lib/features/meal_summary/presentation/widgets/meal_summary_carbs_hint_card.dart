import 'package:flutter/material.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../models/meal_summary_draft.dart';

class MealSummaryCarbsHintCard extends StatelessWidget {
  const MealSummaryCarbsHintCard({super.key, required this.draft});

  final MealSummaryDraft draft;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final extraCarbs = _extraNetCarbs(draft);
    final hasExtraCarbs = extraCarbs >= 0.5;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: hasExtraCarbs
            ? colorScheme.tertiaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              hasExtraCarbs ? Icons.add_chart : Icons.check_circle_outline,
              color: hasExtraCarbs
                  ? colorScheme.onTertiaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasExtraCarbs
                        ? 'Dokładka: +${extraCarbs.round()}g węglowodanów'
                        : 'Bez dodatkowych węglowodanów',
                    style: textTheme.titleMedium?.copyWith(
                      color: hasExtraCarbs
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasExtraCarbs
                        ? 'Tę wartość można wpisać do kalkulatora AAPS jako dodatkowe węglowodany.'
                        : 'Zaznacz większą ilość albo dodaj składnik, jeśli była dokładka.',
                    style: textTheme.bodySmall?.copyWith(
                      color: hasExtraCarbs
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _extraNetCarbs(MealSummaryDraft draft) {
    final plannedItemCarbs = draft.itemsById.values.fold(0.0, (sum, item) {
      final extraAmount = item.consumedAmount - item.plannedAmount;
      if (extraAmount <= 0) return sum;
      return sum + extraAmount * item.netCarbsPerAmount;
    });

    final extraItemCarbs = draft.extraItems.fold(0.0, (sum, item) {
      return sum + _extraItemNetCarbs(item);
    });

    return plannedItemCarbs + extraItemCarbs;
  }

  double _extraItemNetCarbs(MealIngredientsDraft item) {
    final netCarbsPer100g =
        item.ingredient.carbsPer100g - item.ingredient.fiberPer100g;
    final safeNetCarbsPer100g = netCarbsPer100g < 0 ? 0 : netCarbsPer100g;
    final grams = item.ingredient.isReference
        ? item.amount * 100
        : item.ingredientPortion.portion.map(
            empty: (_) => item.amount,
            existing: (_) => item.amount * item.ingredientPortion.amount,
            draft: (_) => item.amount * item.ingredientPortion.amount,
          );

    return grams * safeNetCarbsPer100g / 100;
  }
}
