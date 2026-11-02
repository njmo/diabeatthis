import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/widgets/confidence_slider.dart';
import '../../../../common/widgets/friendly_amount_selector.dart';
import '../controllers/meal_summary_controller.dart';
import '../providers/meal_summary_draft_item_provider.dart';

class MealCompletionIngredientRow extends ConsumerWidget {
  const MealCompletionIngredientRow({
    super.key,
    required this.mealId,
    required this.mealIngredientId,
    required this.onInputValidityChanged,
    this.addOnOnly = false,
    this.showConfidence = false,
  });

  final int mealId;
  final int mealIngredientId;
  final ValueChanged<bool> onInputValidityChanged;
  final bool addOnOnly;
  final bool showConfidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      mealSummaryItemDraftProvider(mealId, mealIngredientId),
    );
    if (item == null) return const SizedBox.shrink();
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);
    final lang = context.lang;
    final theme = Theme.of(context);
    final number = NumberFormat('0.#', lang.localeName);
    String amountLabel(double value) =>
        '${number.format(value)} ${item.amountLabel}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(item.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    lang.mealSummaryPlanAmount(amountLabel(item.plannedAmount)),
                  ),
                  if ((item.reportedAmount - item.plannedAmount).abs() > 0.001)
                    Text(
                      lang.mealCompletionReportedAmount(
                        amountLabel(item.reportedAmount),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                addOnOnly
                    ? lang.mealAddOnTotalAmount
                    : lang.mealSummaryHowMuchEaten,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              FriendlyAmountSelector(
                compact: true,
                value: item.consumedAmount,
                min: addOnOnly ? item.reportedAmount : 0,
                step: item.amountLabel == 'g' ? 5 : 0.5,
                valueLabel: amountLabel,
                options: addOnOnly
                    ? const []
                    : [
                        FriendlyAmountOption(
                          label: lang.mealCompletionNone,
                          value: 0,
                        ),
                        FriendlyAmountOption(
                          label: lang.commonHalf,
                          value: item.reportedAmount * 0.5,
                        ),
                        FriendlyAmountOption(
                          label: lang.mealCompletionWhole,
                          value: item.reportedAmount,
                        ),
                      ],
                onEditingChanged: (editing) => onInputValidityChanged(!editing),
                onChanged: (value) {
                  notifier.setConsumedAmount(mealIngredientId, value);
                  if (!showConfidence && value != item.consumedAmount) {
                    notifier.setConsumedConfidence(mealIngredientId, 1);
                  }
                  onInputValidityChanged(true);
                },
              ),
              if (showConfidence) ...[
                const SizedBox(height: 12),
                ConfidenceSlider(
                  title: lang.mealSummaryConfidenceQuestion,
                  value: ConfidenceLevelX.fromDouble01(item.consumedConfidence),
                  onChanged: (value) => notifier.setConsumedConfidence(
                    mealIngredientId,
                    value.toDouble01(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
