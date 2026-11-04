import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/macro_distribution_bar.dart';
import '../../../../common/widgets/nutrition_metric_tile.dart';
import '../../../../common/widgets/responsive_metric_list.dart';
import '../../domain/models/meal_photo_nutrition.dart';
import '../../domain/models/meal_photo_proposal.dart';
import '../../domain/models/meal_photo_reference_preview_data.dart';
import 'meal_photo_confidence_summary.dart';

class MealPhotoReferencePreview extends StatelessWidget {
  const MealPhotoReferencePreview({
    super.key,
    required this.proposal,
    this.referenceNutrition,
    this.referenceConfidence,
  });
  final MealPhotoProposal proposal;
  final MealPhotoNutrition? referenceNutrition;
  final double? referenceConfidence;
  @override
  Widget build(BuildContext context) {
    final data = MealPhotoReferencePreviewData.fromProposal(
      proposal,
      referenceNutrition: referenceNutrition,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.lang.mealPhotoWholePlateProposal,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(data.name, style: Theme.of(context).textTheme.headlineSmall),
            if ((referenceNutrition ?? proposal.reference.referenceNutrition)
                case final facts?)
              MacroDistributionBar(
                carbs: facts.netCarbs,
                protein: facts.protein,
                fat: facts.fat,
                basisLabel: context.lang.mealPhotoMacrosPerPortion,
              ),
            MealPhotoConfidenceSummary(
              value:
                  referenceConfidence ?? proposal.reference.nutritionConfidence,
              title: context.lang.mealPhotoReferenceConfidence,
            ),
            const SizedBox(height: 16),
            ResponsiveMetricList(
              maxColumns: 2,
              spacing: 12,
              runSpacing: 12,
              children: [
                NutritionMetricTile(
                  icon: Icons.grass_rounded,
                  label: context.lang.mealFlowNetCarbs,
                  value: context.lang.mealStartGrams(data.netCarbsGrams),
                  emphasized: true,
                ),
                NutritionMetricTile(
                  icon: Icons.history_rounded,
                  label: context.lang.mealStartEcarbsLabel,
                  value: context.lang.mealStartGrams(data.extendedCarbsGrams),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
