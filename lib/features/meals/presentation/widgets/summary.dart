import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../portions/data/drafts/portion_draft.dart';
import '../../data/providers/meal_draft_provider.dart';

class AddIngredientSummary extends HookConsumerWidget {
  const AddIngredientSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIngredientsDraft = ref.read(mealIngredientsDraftProvider);

    final unitHint = mealIngredientsDraft.ingredientPortion.portion.map(
      draft: (e) => e.unitHint,
      existing: (e) => e.unitHint,
      empty: (_) => 'grams',
    );

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nazwa: ${mealIngredientsDraft.ingredient.name}'),
            Text('Jednostka: $unitHint'),
            Text('Ilość: ${mealIngredientsDraft.amount}'),
          ],
        ),
      ),
    );
  }
}
