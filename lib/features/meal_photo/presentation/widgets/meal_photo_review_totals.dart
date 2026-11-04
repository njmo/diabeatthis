import 'package:flutter/material.dart';

import '../../../../common/widgets/meal_macro_summary.dart';
import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../domain/models/meal_photo_nutrition.dart';
import '../../domain/models/meal_photo_review_item.dart';

class MealPhotoReviewTotals extends StatelessWidget {
  const MealPhotoReviewTotals({super.key, required this.items});
  final List<MealPhotoReviewItem> items;

  @override
  Widget build(BuildContext context) {
    final facts = items
        .map((item) => item.nutritionForPortion)
        .whereType<MealPhotoNutrition>()
        .toList();
    double total(double Function(MealPhotoNutrition) value) =>
        facts.fold(0, (sum, fact) => sum + value(fact));
    final nutrition = MealPhotoNutrition(
      carbs: total((fact) => fact.netCarbs),
      fiber: total((fact) => fact.fiber),
      fat: total((fact) => fact.fat),
      protein: total((fact) => fact.protein),
      carbsLabelMode: CarbsLabelMode.eu,
    );
    final weight = items.fold(
      0.0,
      (sum, item) => sum + (item.weightGrams ?? 0),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: MealMacroSummary(
        netCarbs: nutrition.netCarbs,
        protein: nutrition.protein,
        fat: nutrition.fat,
        fiber: nutrition.fiber,
        calories: nutrition.kcal,
        weightGrams: weight,
      ),
    );
  }
}
