import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/widgets/friendly_amount_selector.dart';
import '../controllers/meal_summary_controller.dart';
import '../models/meal_summary_item_draft.dart';
import '../providers/meal_summary_draft_item_provider.dart';
import '../utils/meal_summary_formatters.dart';
import 'meal_summary_confidence_selector.dart';

class MealSummaryItemRow extends ConsumerWidget {
  final int mealId;
  final int mealIngredientId;

  const MealSummaryItemRow({
    super.key,
    required this.mealId,
    required this.mealIngredientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(
      mealSummaryItemDraftProvider(mealId, mealIngredientId),
    );
    final notifier = ref.read(mealSummaryControllerProvider(mealId).notifier);

    if (item == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final carbDelta = _netCarbsDelta(item);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Plan: ${formatMealSummaryAmount(item.plannedAmount, item.amountLabel)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (carbDelta.abs() >= 0.5)
                    Chip(
                      avatar: Icon(
                        carbDelta > 0 ? Icons.add : Icons.remove,
                        size: 18,
                      ),
                      label: Text('${_formatSigned(carbDelta.round())}g węgli'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Ile zjadłeś?', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              FriendlyAmountSelector(
                value: item.consumedAmount,
                max: _maxAmount(item),
                step: _amountStep(item),
                options: _amountOptions(item),
                valueLabel: (value) =>
                    formatMealSummaryAmount(value, item.amountLabel),
                onChanged: (value) {
                  notifier.setConsumedAmount(mealIngredientId, value);
                },
              ),
              const SizedBox(height: 12),
              Text('Jak dobrze to pamiętasz?', style: textTheme.labelLarge),
              const SizedBox(height: 8),
              MealSummaryConfidenceSelector(
                value: item.consumedConfidence,
                onChanged: (value) {
                  notifier.setConsumedConfidence(mealIngredientId, value);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<FriendlyAmountOption> _amountOptions(MealSummaryItemDraft item) {
    if (item.amountLabel == 'g') {
      return [
        const FriendlyAmountOption(label: 'Nic', value: 0, icon: Icons.close),
        FriendlyAmountOption(
          label: 'Połowa',
          value: item.plannedAmount * 0.5,
          icon: Icons.pie_chart_outline,
        ),
        FriendlyAmountOption(
          label: 'Plan',
          value: item.plannedAmount,
          icon: Icons.check_circle_outline,
        ),
        FriendlyAmountOption(
          label: 'Więcej',
          value: item.plannedAmount * 1.5,
          icon: Icons.add_circle_outline,
        ),
        FriendlyAmountOption(
          label: '2x plan',
          value: item.plannedAmount * 2,
          icon: Icons.add_chart,
        ),
      ];
    }

    return [
      const FriendlyAmountOption(label: 'Nic', value: 0, icon: Icons.close),
      const FriendlyAmountOption(
        label: 'Pół',
        value: 0.5,
        icon: Icons.pie_chart_outline,
      ),
      const FriendlyAmountOption(
        label: '1 porcja',
        value: 1,
        icon: Icons.check_circle_outline,
      ),
      const FriendlyAmountOption(
        label: '1,5',
        value: 1.5,
        icon: Icons.add_circle_outline,
      ),
      const FriendlyAmountOption(label: '2', value: 2, icon: Icons.add_chart),
      if (item.plannedAmount > 2)
        FriendlyAmountOption(
          label: 'Plan',
          value: item.plannedAmount,
          icon: Icons.flag_outlined,
        ),
    ];
  }

  double _maxAmount(MealSummaryItemDraft item) {
    if (item.amountLabel == 'g') {
      return item.plannedAmount * 2;
    }
    return item.plannedAmount > 2 ? item.plannedAmount * 2 : 2;
  }

  double _amountStep(MealSummaryItemDraft item) {
    return item.amountLabel == 'g' ? 5 : 0.5;
  }

  double _netCarbsDelta(MealSummaryItemDraft item) {
    final amountDelta = item.consumedAmount - item.plannedAmount;
    return amountDelta * item.netCarbsPerAmount;
  }

  String _formatSigned(int value) {
    if (value > 0) {
      return '+$value';
    }
    return value.toString();
  }
}
