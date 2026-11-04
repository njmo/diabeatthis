import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/copied_meal_preview_weight_provider.dart';

class CopiedMealPreviewTotals extends ConsumerWidget {
  const CopiedMealPreviewTotals({super.key, required this.items});

  final List<MealIngredientsDraft> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weight = ref
        .watch(copiedMealPreviewWeightProvider(items))
        .asData
        ?.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Text(
        '${context.lang.copiedMealIngredientCount(items.length)}${weight == null ? '' : ' · ${NumberFormat('0.#', context.lang.localeName).format(weight)} g'}',
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
