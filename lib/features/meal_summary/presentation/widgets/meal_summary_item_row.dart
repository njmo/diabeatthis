import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/meal_summary_controller.dart';
import '../providers/meal_summary_draft_item_provider.dart';

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

    return Column(
      children: [
        ListTile(
          title: Text(item.name),
          subtitle: Text(
            'planned: ${item.plannedAmount} • consumed: ${item.consumedAmount.toStringAsFixed(1)}',
          ),
        ),
        Slider(
          value: item.consumedAmount,
          min: 0,
          max: item.plannedAmount * 2,
          divisions: 10,
          onChanged: (value) {
            notifier.setConsumedAmount(mealIngredientId, value);
          },
        ),
        Slider(
          value: item.consumedConfidence,
          min: 0.25,
          max: 1.0,
          divisions: 3,
          onChanged: (value) {
            notifier.setConsumedConfidence(mealIngredientId, value);
          },
        ),
      ],
    );
  }
}