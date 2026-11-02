import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'meal_ingredient_review_content.dart';

class MealIngredientReview extends ConsumerWidget {
  const MealIngredientReview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(mealIngredientsDraftProvider);
    final storedAmount = draft.shouldLoadStoredPortionAmount
        ? ref.watch(
            gramsPerPortionProvider(
              draft.ingredient,
              draft.ingredientPortion.portion,
            ),
          )
        : null;
    final gramsPerPortion = resolveIngredientGramsPerPortion(
      kind: draft.amountKind,
      portionGrams: draft.ingredientPortion.amount,
      storedGramsPerPortion: storedAmount?.asData?.value,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: MealIngredientReviewContent(
        draft: draft,
        gramsPerPortion: gramsPerPortion,
        isLoadingPortionAmount: storedAmount?.isLoading ?? false,
      ),
    );
  }
}
