import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/meal_template/data/provider/add_meal_template_ingredients_provider.dart';
import 'package:diabeatthis/features/meal_template/data/provider/meal_template_draft_provider.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_filter.dart';
import 'package:diabeatthis/features/portions/data/providers/portion_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('AddMealTemplateIngredientStageNotifier', () {
    test('opens existing portions when modifying existing ingredient', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(mealTemplateIngredientsDraftProvider.notifier)
          .setIngredient(_existingIngredient(id: 21));
      final notifier = container.read(
        addMealTemplateIngredientStageProvider.notifier,
      );

      notifier.modifyIngredientStage(false);

      expect(
        container.read(addMealTemplateIngredientStageProvider),
        AddMealTemplateIngredientStage.definedPortionsSearch,
      );
      expect(
        container.read(portionFilterProvider),
        const PortionFilter.byQueryForIngredient(ingredientId: 21),
      );

      notifier.back();

      expect(
        container.read(addMealTemplateIngredientStageProvider),
        AddMealTemplateIngredientStage.dismiss,
      );
    });
  });
}

IngredientDraft _existingIngredient({required int id}) {
  return IngredientDraft.existing(
    id: id,
    name: 'Ryż',
    carbsPer100g: 25,
    fatPer100g: 1,
    fiberPer100g: 1,
    proteinPer100g: 3,
    nutritionConfidence: 0.9,
    isReference: false,
  );
}
