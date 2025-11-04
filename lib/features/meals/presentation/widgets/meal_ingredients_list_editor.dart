import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/presentation/screens/ingredient_form.dart';
import '../../../ingredients/presentation/screens/ingredient_search.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/presentation/screens/portion_search.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredients_list.dart';
import 'portion_amount_form.dart';

class MealIngredientsListEditor extends ConsumerWidget {
  const MealIngredientsListEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealDraft = ref.watch(mealDraftProvider.notifier);
    final calculatedCarbs = ref.watch(calculatedCarbsProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Align(
                      alignment: AlignmentGeometry.bottomLeft,
                      child: calculatedCarbs.when(
                        data: (value) => Text('Ingredients (calculated carbs: $value g)'),
                        loading: () => const Text('Ingredients (calculating...)'),
                        error: (err, _) => Text('Ingredients (error: $err)'),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final ingredient =
                            await showModalBottomSheet<IngredientSelection>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              isDismissible: false,
                              builder: (_) => AddMealIngredient(),
                            );
                      },
                      child: const Icon(Icons.add_box, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MealIngredientsList(),
        ],
      ),
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showSnackBar(
    BuildContext context,
    String message,
  ) {
    return ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
