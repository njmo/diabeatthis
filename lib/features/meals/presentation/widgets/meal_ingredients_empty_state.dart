import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class MealIngredientsEmptyState extends StatelessWidget {
  const MealIngredientsEmptyState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              Icons.no_meals_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              context.lang.mealNoIngredientsTitle,
              style: textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              context.lang.mealNoIngredientsSubtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(context.lang.mealAddFirstIngredient),
            ),
          ],
        ),
      ),
    );
  }
}
