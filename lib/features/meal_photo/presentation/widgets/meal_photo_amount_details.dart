import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_review_item.dart';

class MealPhotoAmountDetails extends StatelessWidget {
  const MealPhotoAmountDetails({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onNutritionChanged,
    this.initiallyExpanded = false,
  });
  final MealPhotoReviewItem item;
  final bool initiallyExpanded;
  final ValueChanged<double> onQuantityChanged;
  final ValueChanged<double> onNutritionChanged;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: initiallyExpanded,
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    dense: true,
    title: Text(
      context.lang.mealPhotoAmountDetails,
      style: Theme.of(context).textTheme.bodySmall,
    ),
    children: [
      if (item.product != null)
        Align(alignment: Alignment.centerLeft, child: Text(item.product!.name)),
      Text(
        '${context.lang.mealPhotoQuantityConfidence}: ${(item.quantityConfidence * 100).round()}%',
      ),
      Slider(
        value: item.quantityConfidence.clamp(0, 1),
        onChanged: onQuantityChanged,
      ),
      Text(
        '${context.lang.mealPhotoNutritionConfidence}: ${(item.nutritionConfidence * 100).round()}%',
      ),
      if (item.product == null)
        Slider(
          value: item.nutritionConfidence.clamp(0, 1),
          onChanged: onNutritionChanged,
        ),
      if (item.product != null &&
          !item.product!.nutritionConfidenceAssessed &&
          item.nutritionConfidence ==
              item.product!.effectiveNutritionConfidence)
        Text(context.lang.catalogUnassessedConfidence),
    ],
  );
}
