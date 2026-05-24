import 'package:drift/drift.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/database_impl.dart';
import '../../../meals/data/drafts/meal_draft.dart';

extension MealIngredientDraftQuickLowTreatmentItemMapper
    on MealIngredientsDraft {
  QuickLowTreatmentItemCompanion toQuickLowTreatmentItemCompanion({
    required domain.Ingredient ingredient,
    required domain.Portion? portion,
    required int sortOrder,
  }) {
    return QuickLowTreatmentItemCompanion(
      name: Value(ingredient.name),
      ingredientId: Value(ingredient.id),
      portionId: Value(portion?.id),
      amount: Value(amount),
      sortOrder: Value(sortOrder),
    );
  }
}
