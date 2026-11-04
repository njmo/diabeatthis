import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/nutrition/meal_nutrition_totals.dart';
import 'meal_draft_macro_summary_provider.dart';

final mealDraftNutritionTotalsProvider =
    FutureProvider.autoDispose<MealNutritionTotals>((ref) async {
      return MealNutritionTotals.fromMacroSummary(
        await ref.watch(mealDraftMacroSummaryProvider.future),
      );
    });
