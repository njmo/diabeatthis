import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_creation_preview_scope.dart';

class MealPhotoSelectionOrigin extends HookWidget {
  const MealPhotoSelectionOrigin({super.key, required this.item});
  final MealPhotoReviewItem item;

  @override
  Widget build(BuildContext context) {
    final check = MealPhotoCreationPreviewScope.maybeOf(context)?.check;
    final pending = useMemoized(() => check?.call(item), [
      check,
      item.product,
      item.weightGrams,
      item.referenceNutrition,
      item.displayName,
      item.proposal.referenceScope,
    ]);
    final creation = useFuture(pending);
    if (!item.assigned && item.referenceNutrition == null) {
      return const SizedBox.shrink();
    }
    final kind = item.product != null
        ? context.lang.mealPhotoOrdinaryIngredient
        : item.manualReferenceNutrition != null
        ? context.lang.mealPhotoManualReference
        : context.lang.mealPhotoAiReference;
    final method = item.selectionMethod == MealPhotoSelectionMethod.automatic
        ? context.lang.mealPhotoAutomaticChoice
        : context.lang.mealPhotoManualChoice;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$kind · $method',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (creation.connectionState == ConnectionState.done &&
            creation.data == true)
          Tooltip(
            message: context.lang.mealPhotoNewIngredientHint,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  context.lang.mealPhotoNewIngredient,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
