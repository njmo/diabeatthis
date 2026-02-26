import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/providers/meal_add_provider.dart';
import 'meal_status_dialog.dart';

class KidFAB extends HookConsumerWidget {
  const KidFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(
      child: Icon(Icons.bakery_dining_rounded, size: 32),
      onPressed: () async {
        final mealIngredient = await showModalBottomSheet<MealIngredientsDraft>(
          context: context,
          useRootNavigator: false,
          isScrollControlled: true,
          builder: (_) => AddMealIngredient(),
        );
        if (mealIngredient != null) {
          final draft = ref.watch(mealDraftProvider.notifier);
          draft.addMealIngredient(mealIngredient);
          draft.setName("QM: ${mealIngredient.ingredient.name}");
          final addedMeal = ref
              .watch(mealAddProvider.notifier)
              .addMeal(ref.read(mealDraftProvider));
          addedMeal.then((meal) async {
            final action = await showDialog<String?>(
              barrierDismissible: true,
              context: context,
              builder: (context) => MealStatusDialog(meal: meal),
            );
            if (action != null) {
              ref.read(updateMealProvider(meal, action));
            }
          });
        }
      },
    );
  }
}
