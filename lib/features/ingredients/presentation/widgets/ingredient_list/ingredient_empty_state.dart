import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';

class IngredientEmptyState extends StatelessWidget {
  const IngredientEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 36, color: colors.outline),
            const SizedBox(height: 12),
            Text(
              context.lang.ingredientEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.lang.ingredientEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
