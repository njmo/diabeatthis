import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';

class IngredientAmountResult extends StatelessWidget {
  const IngredientAmountResult({
    super.key,
    required this.totalGramsLabel,
    required this.carbsLabel,
    required this.extendedCarbsLabel,
  });

  final String? totalGramsLabel;
  final String carbsLabel;
  final String extendedCarbsLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (totalGramsLabel != null) ...[
          Text(
            '${context.lang.mealTotalMassLabel}: $totalGramsLabel',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.grain,
                label: context.lang.mealCarbsLabel,
                value: carbsLabel,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NutritionMetricTile(
                icon: Icons.schedule_outlined,
                label: 'eCarbs',
                value: extendedCarbsLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
