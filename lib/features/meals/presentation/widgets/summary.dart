import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/providers/meal_draft_provider.dart';

class AddIngredientSummary extends HookConsumerWidget {
  AddIngredientSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIngredientsDraft = ref.read(mealIngredientsDraftProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nazwa: ${mealIngredientsDraft.ingredient.name}'),
            Text('Jednostka: ${mealIngredientsDraft.ingredientPortion.portion.unitHint}'),
            Text('Ilość: ${mealIngredientsDraft.amount}'),
          ],
        ),
      ),
    );
  }
}
