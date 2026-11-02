import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../dashboard/presentation/widgets/nutrient_summary_chart.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/mapper/meal_ingredient_template_mapper.dart';
import '../../data/provider/meal_template_draft_provider.dart';
import '../../data/provider/meal_template_ingredients_list_provider.dart';
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
            error: (err, _) =>
                Text(context.lang.templateIngredientsError(err.toString())),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      context.lang.uiIngredientsList,
                      style: TextStyle(fontSize: 20),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () async {
                        final ingredient = await showAddMealIngredientSheet(
                          context: context,
                          ref: ref,
                        );
                        if (ingredient != null && context.mounted) {
                          ref
                              .read(mealTemplateDraftProvider.notifier)
                              .addMealTemplateIngredient(
                                ingredient.toTemplateIngredient(),
                              );
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
