import '../../../../core/domain/model/quick_low_treatment_item.dart';
import '../../../ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/mappers/portion_draft_mapper.dart';

extension QuickLowTreatmentItemMealDraftMapper on QuickLowTreatmentItem {
  MealIngredientsDraft toMealIngredientDraft({int quantity = 1}) {
    return MealIngredientsDraft(
      ingredient: ingredient.toDraft(),
      ingredientPortion: IngredientPortionDraft(
        portion: portion == null
            ? const PortionSelection.empty()
            : portion!.toSelection(),
        amount: gramsPerPortion ?? 0,
      ),
      amount: amount * quantity,
      quantityConfidence: 1,
      entryType: 'planned',
      consumedAmount: null,
      consumedConfidence: null,
    );
  }
}
