import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../portions/data/drafts/portion_draft.dart';
import '../domain/use_cases/resolve_meal_ingredient_grams_use_case.dart';
import '../drafts/meal_draft.dart';

/// Omit total weight when even one ingredient has an unknown portion mass.
final copiedMealPreviewWeightProvider = FutureProvider.autoDispose
    .family<double?, List<MealIngredientsDraft>>((ref, items) async {
      final resolve = ResolveMealIngredientGramsUseCase(ref);
      var total = 0.0;
      for (final item in items) {
        if (item.recordedGramsPerAmount == null &&
            item.ingredientPortion.amount <= 0 &&
            item.ingredientPortion.portion.maybeMap(
              draft: (_) => true,
              orElse: () => false,
            )) {
          return null;
        }
        final grams = await resolve(item);
        if (!grams.isFinite || grams <= 0) return null;
        total += grams;
      }
      return total;
    });
