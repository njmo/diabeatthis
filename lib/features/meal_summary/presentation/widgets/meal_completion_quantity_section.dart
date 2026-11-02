import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/meal_completion/meal_completion_actions.dart';
import '../models/meal_completion_portion_choice.dart';
import '../models/meal_summary_draft.dart';
import 'meal_completion_ingredient_row.dart';
import 'meal_summary_extra_items_section.dart';

class MealCompletionQuantitySection extends StatelessWidget {
  const MealCompletionQuantitySection({
    super.key,
    required this.draft,
    required this.choice,
    required this.onChoiceChanged,
    required this.onInputValidityChanged,
    this.enabled = true,
    this.showChoice = true,
    this.addOnOnly = false,
    this.showConfidence = false,
    this.requiresBolus = false,
    this.onAddFood,
  });

  final MealSummaryDraft draft;
  final MealCompletionPortionChoice? choice;
  final ValueChanged<MealCompletionPortionChoice> onChoiceChanged;
  final ValueChanged<bool> onInputValidityChanged;
  final bool enabled;
  final bool showChoice;
  final bool addOnOnly;
  final bool showConfidence;
  final bool requiresBolus;
  final VoidCallback? onAddFood;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AbsorbPointer(
      absorbing: !enabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showChoice) ...[
            Text(
              lang.mealCompletionQuestion,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            MealCompletionActions(
              primaryLabel: lang.mealCompletionAsPlannedAction,
              primaryDescription: lang.mealCompletionAllHint,
              secondaryLabel: lang.mealCompletionAdjustedAction,
              secondaryDescription: lang.mealCompletionAdjustedHint,
              onPrimaryPressed: enabled
                  ? () {
                      onInputValidityChanged(true);
                      onChoiceChanged(MealCompletionPortionChoice.asReported);
                    }
                  : null,
              onSecondaryPressed:
                  enabled && choice != MealCompletionPortionChoice.adjusted
                  ? () {
                      onInputValidityChanged(true);
                      onChoiceChanged(MealCompletionPortionChoice.adjusted);
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              requiresBolus || draft.mealStatus == 'eating-then-bolus'
                  ? lang.mealCompletionSaveImmediatelyBeforeBolus
                  : lang.mealCompletionSaveImmediately,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (choice == MealCompletionPortionChoice.adjusted) ...[
            const SizedBox(height: 12),
            for (final id in draft.itemIds)
              MealCompletionIngredientRow(
                key: ValueKey(id),
                mealId: draft.mealId,
                mealIngredientId: id,
                onInputValidityChanged: onInputValidityChanged,
                addOnOnly: addOnOnly,
                showConfidence: showConfidence,
              ),
            const SizedBox(height: 4),
            MealSummaryExtraItemsSection(
              mealId: draft.mealId,
              items: draft.extraItems,
              showConfidence: showConfidence,
              onAddFood: onAddFood,
            ),
          ],
        ],
      ),
    );
  }
}
