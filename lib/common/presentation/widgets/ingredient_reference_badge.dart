import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class IngredientReferenceBadge extends StatelessWidget {
  const IngredientReferenceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 15,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 5),
            Text(
              context.lang.ingredientReferenceShort,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
