import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../data/drafts/meal_draft.dart';
import 'copied_meal_ingredient_row.dart';

class CopiedMealPreviewIngredientList extends HookWidget {
  const CopiedMealPreviewIngredientList({super.key, required this.items});

  final List<MealIngredientsDraft> items;

  @override
  Widget build(BuildContext context) {
    final rowHeight = 96.0 * MediaQuery.textScalerOf(context).scale(14) / 14;
    final controller = useScrollController();
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: rowHeight * 3),
              child: Scrollbar(
                controller: controller,
                thumbVisibility: true,
                radius: const Radius.circular(4),
                child: ListView.builder(
                  controller: controller,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemExtent: rowHeight,
                  itemCount: items.length,
                  itemBuilder: (_, index) => Column(
                    children: [
                      Expanded(
                        child: CopiedMealIngredientRow(item: items[index]),
                      ),
                      if (index < items.length - 1)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (items.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    context.lang.copiedMealScrollIngredients,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
