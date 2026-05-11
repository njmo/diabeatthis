import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import 'add_meal_ingredient.dart';
import 'meal_ingredients_list.dart';

class MealIngredientsListEditor extends ConsumerWidget {
  const MealIngredientsListEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculatedMacronutrients = ref.watch(
      calculatedMacronutrientsProvider,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          calculatedMacronutrients.when(
            data: (value) => NutrientSummaryChart(macros: value),
            loading: () => const CircularProgressIndicator(),
            error: (err, _) => Text('Składniki (błąd: $err)'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text('Lista składników:', style: TextStyle(fontSize: 20)),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final mealIngredient =
                            await showModalBottomSheet<MealIngredientsDraft>(
                              context: context,
                              useRootNavigator: false,
                              isScrollControlled: true,
                              builder: (_) => AddMealIngredient(),
                            );
                        if (mealIngredient != null) {
                          ref
                              .read(mealDraftProvider.notifier)
                              .addMealIngredient(mealIngredient);
                        }
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
}
