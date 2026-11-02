import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../../common/nutrition/ingredient_amount_kind.dart';
import '../../../../ingredients/data/mappers/ingredient_draft_mapper.dart';
import '../../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../../portions/data/drafts/portion_draft.dart';
import '../../../../portions/data/mappers/portion_draft_mapper.dart';
import '../../drafts/meal_draft.dart';

class ResolveMealIngredientGramsUseCase {
  const ResolveMealIngredientGramsUseCase(this.ref);
  final Ref ref;

  Future<double> call(MealIngredientsDraft mi) async {
    final isReference = mi.ingredient.isReference;
    var portionAmount = mi.ingredientPortion.amount;
    final isEmpty = mi.ingredientPortion.portion.maybeMap(
      orElse: () => false,
      empty: (empty) => true,
    );

    if (!isEmpty && portionAmount == 0) {
      final ingredientDomain = mi.ingredient.toDomain();
      final portionDomain = mi.ingredientPortion.portion.toDomain();

      final fetched = await ref.read(
        getAmountForPortionIngredientProvider(
          ingredientDomain,
          portionDomain,
        ).future,
      );

      portionAmount = fetched ?? 0;
    }
    final gramsPerPortion =
        resolveIngredientGramsPerPortion(
          kind: !isEmpty
              ? IngredientAmountKind.portion
              : isReference
              ? IngredientAmountKind.referencePortion
              : IngredientAmountKind.grams,
          portionGrams: portionAmount,
          // Keep aggregation's resolved weight, including legacy zero/negative values.
          storedGramsPerPortion: portionAmount,
        ) ??
        0;
    return mi.amount * gramsPerPortion;
  }
}
