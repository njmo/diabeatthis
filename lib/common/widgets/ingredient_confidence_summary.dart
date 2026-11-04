import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../nutrition/confidence_level.dart';
import '../nutrition/ingredient_confidence.dart';
import 'confidence_slider.dart';

/// Shows the two independent assessments and their combined meal contribution.
class IngredientConfidenceSummary extends StatelessWidget {
  const IngredientConfidenceSummary({
    super.key,
    required this.nutritionConfidence,
    required this.quantityConfidence,
  });

  final double? nutritionConfidence;
  final double? quantityConfidence;

  @override
  Widget build(BuildContext context) {
    bool valid(double? value) =>
        value != null && value.isFinite && value >= 0 && value <= 1;
    String label(double? value) => valid(value)
        ? ConfidenceLevelX.fromDouble01(value!).label
        : context.lang.confidenceNotAvailable;
    final combined = valid(nutritionConfidence) && valid(quantityConfidence)
        ? combineIngredientConfidence(
            nutritionConfidence: nutritionConfidence!,
            quantityConfidence: quantityConfidence!,
          )
        : null;
    return Text(
      context.lang.mealIngredientConfidenceSummary(
        label(nutritionConfidence),
        label(quantityConfidence),
        label(combined),
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
