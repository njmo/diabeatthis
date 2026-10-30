import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../../common/widgets/value_change_row.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/models/ingredient_history_entry_data.dart';
import '../../data/models/ingredient_nutrition_values.dart';
import '../utils/reference_ingredient_macro_calculator.dart';

class IngredientHistoryChangeCard extends StatelessWidget {
  const IngredientHistoryChangeCard({
    super.key,
    required this.entry,
    required this.after,
    required this.isReference,
  });

  final IngredientHistoryEntryData entry;
  final IngredientNutritionValues after;
  final bool isReference;

  @override
  Widget build(BuildContext context) {
    final before = IngredientNutritionValues.history(entry);
    final lang = context.lang;
    final changes = <Widget>[];
    void addMacro(String label, double oldValue, double newValue) {
      if ((oldValue - newValue).abs() > 0.000001) {
        changes.add(
          ValueChangeRow(
            label: label,
            before: '${formatReferenceMacroInput(oldValue)} g',
            after: '${formatReferenceMacroInput(newValue)} g',
          ),
        );
      }
    }

    if (before.confidence != after.confidence) {
      final oldLevel = ConfidenceLevelX.fromDouble01(before.confidence);
      final newLevel = ConfidenceLevelX.fromDouble01(after.confidence);
      changes.add(
        ValueChangeRow(
          label: lang.ingredientDataConfidence,
          before: oldLevel == newLevel
              ? lang.ingredientConfidenceScore(
                  oldLevel.label,
                  (before.confidence * 100).round(),
                )
              : oldLevel.label,
          after: oldLevel == newLevel
              ? lang.ingredientConfidenceScore(
                  newLevel.label,
                  (after.confidence * 100).round(),
                )
              : newLevel.label,
        ),
      );
    }
    addMacro(
      isReference ? lang.ingredientSimpleCarbsLabel : lang.mealCarbsLabel,
      before.carbs,
      after.carbs,
    );
    if (isReference) {
      addMacro(
        lang.ingredientExtendedCarbsLabel,
        referenceExtendedCarbsPer100g(
          fatPer100g: before.fat,
          proteinPer100g: before.protein,
        ),
        referenceExtendedCarbsPer100g(
          fatPer100g: after.fat,
          proteinPer100g: after.protein,
        ),
      );
      final oldFat =
          (referenceFatShare(
                    fatPer100g: before.fat,
                    proteinPer100g: before.protein,
                  ) *
                  100)
              .round();
      final newFat =
          (referenceFatShare(
                    fatPer100g: after.fat,
                    proteinPer100g: after.protein,
                  ) *
                  100)
              .round();
      if (oldFat != newFat) {
        changes.add(
          ValueChangeRow(
            label: lang.ingredientExtendedSplitTitle,
            before: lang.ingredientEcarbsSplit(100 - oldFat, oldFat),
            after: lang.ingredientEcarbsSplit(100 - newFat, newFat),
          ),
        );
      }
    } else {
      addMacro(lang.mealFatLabel, before.fat, after.fat);
      addMacro(lang.mealProteinLabel, before.protein, after.protein);
    }
    addMacro(lang.mealFiberLabel, before.fiber, after.fiber);
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            DateFormat.yMMMd(lang.localeName).add_Hm().format(entry.createdAt),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          ...changes,
          if (before.sameMacros(after)) ...[
            const SizedBox(height: 4),
            Text(
              lang.ingredientNutritionUnchanged,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (before.confidence == after.confidence) ...[
            const SizedBox(height: 4),
            Text(
              '${lang.ingredientDataConfidence}: ${ConfidenceLevelX.fromDouble01(after.confidence).label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
