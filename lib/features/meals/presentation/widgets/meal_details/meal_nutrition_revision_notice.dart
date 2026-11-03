import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../data/mappers/meal_nutrition_revision_mapper.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_formatters.dart';

class MealNutritionRevisionNotice extends StatelessWidget {
  final MealDetailsData details;

  const MealNutritionRevisionNotice({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final revisions = const MealNutritionRevisionMapper().map(details);
    if (revisions.isEmpty) return const SizedBox.shrink();
    final lang = context.lang;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: Text(
          revisions.any((revision) => revision.confidenceIncreased)
              ? lang.mealNutritionRefinedTitle
              : lang.mealNutritionUpdatedTitle,
        ),
        subtitle: Text(lang.mealNutritionRecordedUnchanged),
        children: [
          for (final revision in revisions)
            ListTile(
              title: Text(revision.name),
              subtitle: Text(
                revision.historicalUnavailable
                    ? lang.mealNutritionHistoryMissing
                    : lang.mealNutritionRevisionValues(
                        formatGrams(
                          revision.grams *
                              revision.recordedPer100g['net_carbs_g']! /
                              100,
                        ),
                        formatGrams(
                          revision.grams *
                              revision.currentPer100g['net_carbs_g']! /
                              100,
                        ),
                        formatConfidence(revision.recordedConfidence),
                        formatConfidence(revision.currentConfidence),
                      ),
              ),
              trailing: revision.confidenceIncreased
                  ? Tooltip(
                      message: lang.mealNutritionConfidenceIncreased,
                      child: const Icon(Icons.fact_check_outlined),
                    )
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(lang.mealNutritionRevisionCaution),
          ),
        ],
      ),
    );
  }
}
