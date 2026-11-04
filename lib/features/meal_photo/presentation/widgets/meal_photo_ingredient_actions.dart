import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_confidence_summary.dart';

enum MealPhotoIngredientAction { product, reference, editReference, remove }

class MealPhotoIngredientActions extends StatelessWidget {
  const MealPhotoIngredientActions({
    super.key,
    required this.item,
    required this.onAssign,
    required this.onReference,
    required this.allowProduct,
    this.onCreateReference,
    this.onRemove,
  });
  final MealPhotoReviewItem item;
  final VoidCallback onAssign;
  final VoidCallback onReference;
  final bool allowProduct;
  final VoidCallback? onCreateReference;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PopupMenuButton<MealPhotoIngredientAction>(
        tooltip: context.lang.mealPhotoEditIngredient,
        icon: const Icon(Icons.edit_outlined),
        onSelected: (action) {
          switch (action) {
            case MealPhotoIngredientAction.product:
              onAssign();
            case MealPhotoIngredientAction.reference:
              onReference();
            case MealPhotoIngredientAction.editReference:
              onCreateReference?.call();
            case MealPhotoIngredientAction.remove:
              onRemove?.call();
          }
        },
        itemBuilder: (context) => [
          if (allowProduct)
            PopupMenuItem(
              value: MealPhotoIngredientAction.product,
              child: Text(
                (item.product ?? item.suggestedProduct) != null
                    ? context.lang.mealPhotoChooseAnotherProduct
                    : context.lang.mealPhotoAssign,
              ),
            ),
          if (item.referenceNutrition != null)
            PopupMenuItem(
              value: MealPhotoIngredientAction.reference,
              enabled: !item.referenceAccepted,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.referenceAccepted
                        ? context.lang.mealPhotoReferenceAccepted
                        : context.lang.mealPhotoAcceptReference,
                  ),
                  MealPhotoConfidenceSummary(
                    value: item.referenceNutritionConfidence,
                    title: context.lang.confidenceTitle,
                  ),
                ],
              ),
            ),
          if (onCreateReference != null)
            PopupMenuItem(
              value: MealPhotoIngredientAction.editReference,
              child: Text(
                item.referenceNutrition != null
                    ? context.lang.ingredientEditReferenceData
                    : context.lang.mealPhotoAddReference,
              ),
            ),
        ],
      ),
      if (onRemove != null)
        IconButton(
          onPressed: onRemove,
          tooltip: context.lang.mealPhotoRemoveIngredient,
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
}
