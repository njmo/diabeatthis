import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_category.dart';

/// Anchors the choices to their trigger; the popup route handles screen insets.
Future<MealCategory?> showMealCategoryMenu(
  BuildContext context, {
  MealCategory? selected,
}) {
  final target = context.findRenderObject() as RenderBox;
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
  final bottomLeft = target.localToGlobal(
    Offset(0, target.size.height),
    ancestor: overlay,
  );
  final bottomRight = target.localToGlobal(
    target.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  return showMenu<MealCategory>(
    context: context,
    semanticLabel: context.lang.mealCategoryLabel,
    position: RelativeRect.fromRect(
      Rect.fromPoints(bottomLeft, bottomRight),
      Offset.zero & overlay.size,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
    items: [
      for (final category in MealCategory.values)
        PopupMenuItem(
          value: category,
          child: Row(
            children: [
              Expanded(child: Text(category.label(context.lang))),
              if (category == selected) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.check,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
    ],
  );
}
