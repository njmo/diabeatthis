import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../ingredients/data/providers/ingredient_portion_suggestions_provider.dart';
import '../../../ingredients/presentation/widgets/ingredient_creation_methods.dart';
import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_photo_scan.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'amount_form.dart';
import 'meal_ingredient_review.dart';

class AddMealIngredientBody extends ConsumerWidget {
  const AddMealIngredientBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(addMealIngredientStageProvider);
    final controller = ref.read(addMealIngredientStageProvider.notifier);
    final draft = ref.watch(mealIngredientsDraftProvider);
    return switch (stage) {
      AddMealIngredientStage.dismiss => const SizedBox.shrink(),
      AddMealIngredientStage.ingredientSearch => const IngredientSearch(),
      AddMealIngredientStage.ingredientCreationMethod =>
        const IngredientCreationMethods(),
      AddMealIngredientStage.ingredientPhotoScan => const IngredientPhotoScan(),
      AddMealIngredientStage.ingredientForm => const IngredientForm(
        sectioned: true,
        showReferenceToggle: false,
      ),
      AddMealIngredientStage.referenceIngredientForm => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (draft.ingredient.isReference) ...[
            Text(context.lang.ingredientReferenceEditHint),
            const SizedBox(height: 12),
          ],
          const IngredientForm(sectioned: true, showReferenceToggle: false),
        ],
      ),
      AddMealIngredientStage.portionAddNewSearch => PortionSearch(
        ingredient: draft.ingredient,
        onCreatePortion: controller.toOppositeStage,
        createPortionLabel: context.lang.ingredientCreatePortionName,
        suggestions: ref.watch(ingredientPortionSuggestionsProvider),
        onSuggestionSelected: controller.selectSuggestedPortion,
      ),
      AddMealIngredientStage.definedPortionsSearch => PortionSearch(
        ingredient: draft.ingredient,
        onCreatePortion: controller.toOppositeStage,
        createPortionLabel: context.lang.ingredientDefineNewPortion,
      ),
      AddMealIngredientStage.portionAddNewForm => PortionForm(),
      AddMealIngredientStage.portionSpecifyAmount => IngredientPortionAmountForm(
        portionLabel:
            '${draft.ingredient.name} · ${unitLabelForAmount(1, draft.portionCountUnitLabel)}',
        amount: draft.ingredientPortion.amount,
        onAmountChanged: ref
            .read(mealIngredientsDraftProvider.notifier)
            .setIngredientPortionAmount,
      ),
      AddMealIngredientStage.amountForm => AmountForm(
        onEditReference: draft.ingredient.isReference
            ? controller.editReferenceIngredient
            : null,
      ),
      AddMealIngredientStage.summary => const MealIngredientReview(),
    };
  }
}
