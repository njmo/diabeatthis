import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_template/data/drafts/template_meal_draft.dart';
import 'package:diabeatthis/features/meal_template/data/provider/meal_template_draft_provider.dart';
import 'package:diabeatthis/features/meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  test(
    'meal preview rounds combined split ingredient carbs once (10.4 + 10.4 = 21)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = container.read(mealDraftProvider.notifier);
      expect(draft.addMealIngredient(_mealIngredient(id: 1)), isTrue);
      expect(draft.addMealIngredient(_mealIngredient(id: 2)), isTrue);
      expect(container.read(mealDraftIngredientsProvider), hasLength(2));

      final macros = await container.read(
        calculatedMacronutrientsProvider.future,
      );

      expect(macros.carbsTotal, 21);
    },
  );

  test(
    'meal template preview rounds combined split ingredient carbs once (10.4 + 10.4 = 21)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = container.read(mealTemplateDraftProvider.notifier);
      draft.addMealTemplateIngredient(_templateIngredient(id: 1));
      draft.addMealTemplateIngredient(_templateIngredient(id: 2));
      expect(
        container.read(mealTemplateDraftIngredientsProvider),
        hasLength(2),
      );

      final macros = await container.read(
        calculatedTemplateMacronutrientsProvider.future,
      );

      expect(macros.carbsTotal, 21);
    },
  );
}

MealIngredientsDraft _mealIngredient({required int id}) => MealIngredientsDraft(
  ingredient: _ingredient(id: id),
  ingredientPortion: const IngredientPortionDraft(
    portion: PortionSelection.empty(),
    amount: 1,
  ),
  amount: 52,
  quantityConfidence: 1,
  entryType: 'planned',
  consumedAmount: null,
  consumedConfidence: null,
);

MealTemplateIngredientsDraft _templateIngredient({required int id}) =>
    MealTemplateIngredientsDraft(
      ingredient: _ingredient(id: id),
      ingredientPortion: const IngredientPortionDraft(
        portion: PortionSelection.empty(),
        amount: 1,
      ),
      defaultAmount: 52,
      isOptional: false,
      quantityConfidence: 1,
      prepMethod: '',
      notes: '',
    );

IngredientDraft _ingredient({required int id}) => IngredientDraft.existing(
  id: id,
  name: 'Food $id',
  carbsPer100g: 20,
  fatPer100g: 0,
  fiberPer100g: 0,
  proteinPer100g: 0,
  nutritionConfidence: 1,
  isReference: false,
);
