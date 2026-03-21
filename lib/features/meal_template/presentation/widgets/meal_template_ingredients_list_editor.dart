import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/data/providers/meal_ingredients_list_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../../meals/presentation/widgets/meal_ingredients_list.dart';
import '../../data/drafts/template_meal_draft.dart';
import '../../data/provider/meal_template_draft_provider.dart';
import '../../data/provider/meal_template_ingredients_list_provider.dart';
import 'add_meal_template_ingredient.dart';
import 'meal_template_ingredients_list.dart';

class MealTemplateIngredientsListEditor extends ConsumerWidget {
  const MealTemplateIngredientsListEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calculatedTemplateMacronutrients = ref.watch(
      calculatedTemplateMacronutrientsProvider,
    );

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          calculatedTemplateMacronutrients.when(
            data: (value) => NutrientSummaryChart(macros: value),
            loading: () => const CircularProgressIndicator(),
            error: (err, _) => Text('Ingredients (error: $err)'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text('Ingredients list:', style: TextStyle(fontSize: 20),),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final mealTemplateIngredient = await showModalBottomSheet<MealTemplateIngredientsDraft>(
                          context: context,
                          useRootNavigator: false,
                          isScrollControlled: true,
                          builder: (_) => AddMealTemplateIngredient(),
                        );
                        if (mealTemplateIngredient != null) {
                          ref.read(mealTemplateDraftProvider.notifier).addMealTemplateIngredient(mealTemplateIngredient);
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
          MealTemplateIngredientsList(),
        ],
      ),
    );
  }
}
