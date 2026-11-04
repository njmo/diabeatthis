import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_nutrition.dart';

class MealPhotoNutritionSummary extends StatelessWidget {
  const MealPhotoNutritionSummary({super.key, required this.nutrition});
  final MealPhotoNutrition nutrition;
  @override
  Widget build(BuildContext context) => Text(
    context.lang.mealPhotoNutritionSummary(
      nutrition.netCarbs.toStringAsFixed(1),
      nutrition.fiber.toStringAsFixed(1),
      nutrition.protein.toStringAsFixed(1),
      nutrition.fat.toStringAsFixed(1),
      nutrition.kcal.round().toString(),
    ),
  );
}
