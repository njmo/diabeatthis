import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/meal_template/data/mapper/meal_ingredient_template_mapper.dart';
import 'package:diabeatthis/features/meal_template/data/provider/meal_template_draft_provider.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  for (final kind in ['assigned portion', 'grams', 'reference']) {
    test(
      'shared ingredient result retains $kind, nutrition and confidence in a template',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(mealTemplateDraftProvider, (_, _) {});
        final reference = kind == 'reference';
        final source = MealIngredientsDraft(
          ingredient: IngredientDraft.existing(
            id: 12,
            name: reference ? 'Reference meal' : 'Yogurt',
            brand: 'Saved brand',
            iconAssetPath: 'assets/icons/food/yogurt.png',
            carbsPer100g: 5,
            fatPer100g: 3,
            fiberPer100g: 1,
            proteinPer100g: 4,
            nutritionConfidence: 0.75,
            isReference: reference,
          ),
          ingredientPortion: IngredientPortionDraft(
            portion: kind == 'assigned portion'
                ? const PortionSelection.existing(
                    id: 8,
                    name: 'Cup',
                    unitHint: 'g',
                  )
                : const PortionSelection.empty(),
            amount: kind == 'assigned portion' ? 150 : 0,
          ),
          amount: kind == 'grams' ? 175 : 1.5,
          quantityConfidence: 0.5,
          entryType: 'planned',
          consumedAmount: null,
          consumedConfidence: null,
        );

        container
            .read(mealTemplateDraftProvider.notifier)
            .addMealTemplateIngredient(source.toTemplateIngredient());
        final saved = container
            .read(mealTemplateDraftProvider)
            .mealIngredients
            .single;

        expect(saved.ingredient, source.ingredient);
        expect(saved.ingredientPortion, source.ingredientPortion);
        expect(saved.defaultAmount, source.amount);
        expect(saved.quantityConfidence, 0.5);
        expect(saved.ingredient.nutritionConfidence, 0.75);
        expect(saved.isOptional, isFalse);
        expect(saved.prepMethod, isEmpty);
        expect(saved.notes, isEmpty);
      },
    );
  }
}
