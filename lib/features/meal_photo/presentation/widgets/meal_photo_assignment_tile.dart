import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/confidence_slider.dart';
import '../../../../common/widgets/macro_distribution_bar.dart';
import '../../../../common/widgets/portion_amount_field.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_confidence_summary.dart';
import 'meal_photo_ingredient_actions.dart';
import 'meal_photo_selection_origin.dart';

class MealPhotoAssignmentTile extends HookWidget {
  const MealPhotoAssignmentTile({
    super.key,
    required this.item,
    required this.onAssign,
    required this.onReference,
    this.allowProduct = true,
    this.onCreateReference,
    this.onRemove,
    this.onAmountChanged,
    this.onConfirm,
    this.onNutritionConfidenceChanged,
  });
  final MealPhotoReviewItem item;
  final VoidCallback onAssign;
  final VoidCallback onReference;
  final bool allowProduct;
  final VoidCallback? onCreateReference;
  final VoidCallback? onRemove;
  final ValueChanged<double>? onAmountChanged;
  final VoidCallback? onConfirm;
  final ValueChanged<double>? onNutritionConfidenceChanged;

  @override
  Widget build(BuildContext context) {
    final amount = useTextEditingController(
      text: item.weightGrams == null || !item.weightGrams!.isFinite
          ? ''
          : item.weightGrams! % 1 == 0
          ? item.weightGrams!.toInt().toString()
          : item.weightGrams.toString(),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                MealPhotoIngredientActions(
                  item: item,
                  onAssign: onAssign,
                  onReference: onReference,
                  allowProduct: allowProduct,
                  onCreateReference: onCreateReference,
                  onRemove: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 4),
            MealPhotoSelectionOrigin(item: item),
            const SizedBox(height: 4),
            if (item.product?.name != item.displayName)
              Text(
                item.product?.name ??
                    (item.referenceNutrition != null
                        ? context.lang.ingredientReferenceValues
                        : context.lang.mealPhotoChooseSource),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (onAmountChanged != null)
              PortionAmountField(
                controller: amount,
                label: context.lang.mealPhotoGrams,
                onChanged: (value) => onAmountChanged!(
                  double.tryParse(value.replaceAll(',', '.')) ?? 0,
                ),
              ),
            if ((item.product?.nutritionPer100g ?? item.referenceNutrition)
                case final facts?)
              MacroDistributionBar(
                compact: true,
                carbs: facts.netCarbs,
                protein: facts.protein,
                fat: facts.fat,
                basisLabel: item.product == null
                    ? context.lang.mealPhotoMacrosPerPortion
                    : context.lang.ingredientMacroPer100gTitle,
              ),
            if (onNutritionConfidenceChanged != null)
              ConfidenceSlider(
                value: ConfidenceLevelX.fromDouble01(item.nutritionConfidence),
                title: item.product != null
                    ? context.lang.mealPhotoProductConfidence
                    : context.lang.mealPhotoReferenceConfidence,
                onChanged: (value) =>
                    onNutritionConfidenceChanged!(value.toDouble01()),
              )
            else
              MealPhotoConfidenceSummary(
                value:
                    item.product?.effectiveNutritionConfidence ??
                    item.referenceNutritionConfidence,
                title: item.product != null
                    ? context.lang.mealPhotoProductConfidence
                    : context.lang.mealPhotoReferenceConfidence,
              ),
            if (onAmountChanged != null) ...[
              const SizedBox(height: 8),
              FilledButton(
                onPressed: item.assigned && item.validWeight ? onConfirm : null,
                child: Text(context.lang.mealPhotoAcceptPortion),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
