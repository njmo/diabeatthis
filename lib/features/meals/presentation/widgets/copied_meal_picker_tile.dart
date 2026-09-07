import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/model/copied_meal_type.dart';

class CopiedMealPickerTile extends StatelessWidget {
  const CopiedMealPickerTile({
    super.key,
    required this.copiedMeal,
    required this.onPreview,
    required this.onUse,
  });

  final CopiedMealType copiedMeal;
  final VoidCallback onPreview;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTemplate = copiedMeal is CopiedMealFromTemplate;
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPreview,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                child: Icon(
                  isTemplate
                      ? Icons.bookmark_outline
                      : Icons.restaurant_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      copiedMeal.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      MaterialLocalizations.of(
                        context,
                      ).formatMediumDate(copiedMeal.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.lang.copiedMealPreview,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onUse,
                tooltip: context.lang.copiedMealUseIngredients,
                icon: const Icon(Icons.content_copy_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
