import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../ingredients/data/icons/ingredient_icon_provider.dart';
import '../../../ingredients/presentation/widgets/ingredient_icon.dart';
import '../../../ingredients/presentation/widgets/ingredient_identity_text.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';

class MealIngredientPreviewTile extends ConsumerWidget {
  const MealIngredientPreviewTile({
    super.key,
    required this.draft,
    this.onRemove,
    this.onEdit,
    this.compact = false,
  });

  final MealIngredientsDraft draft;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final portionInfo = _portionInfo(context, ref, draft);
    final iconPath =
        draft.ingredient.iconAssetPath ??
        ref
            .watch(
              ingredientIconSuggestionProvider((
                draft.ingredient.name,
                draft.ingredient.brand,
              )),
            )
            .asData
            ?.value;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: compact ? colorScheme.surfaceContainerLowest : null,
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(
              alpha: compact ? .25 : 1,
            ),
          ),
          borderRadius: BorderRadius.circular(compact ? 20 : 8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 12, right: 4),
          leading: compact ? null : IngredientIcon(assetPath: iconPath),
          title: IngredientIdentityText(
            name: draft.ingredient.name,
            brand: draft.ingredient.brand,
            spacing: 1,
          ),
          subtitle: Text(portionInfo),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onEdit != null)
                IconButton(
                  tooltip: context.lang.mealEditIngredientTooltip,
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              if (onRemove != null)
                IconButton(
                  tooltip: context.lang.mealRemoveIngredientTooltip,
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _portionInfo(
    BuildContext context,
    WidgetRef ref,
    MealIngredientsDraft draft,
  ) {
    var portionAmount = draft.ingredientPortion.amount;
    final amount = draft.amount;

    if (!draft.ingredient.isReference && portionAmount == 0) {
      portionAmount = ref
          .watch(
            gramsPerPortionProvider(
              draft.ingredient,
              draft.ingredientPortion.portion,
            ),
          )
          .when(
            data: (value) => value ?? 0,
            error: (error, stackTrace) => 0,
            loading: () => 0,
          );
    }

    return draft.ingredientPortion.portion.when(
      draft: (name, hint) => '$amount x $name: ${portionAmount * amount}$hint',
      existing: (id, name, hint) {
        if (portionAmount == 0) {
          return '$amount x $name';
        }
        return '$amount x $name: ${amount * portionAmount}$hint';
      },
      empty: () => draft.ingredient.isReference
          ? context.lang.mealReferencePortions(amount)
          : '${amount}g',
    );
  }
}
