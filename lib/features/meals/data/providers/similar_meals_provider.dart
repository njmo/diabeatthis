import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import '../../../meal_analysis/domain/models/meal_composition.dart';
import '../../../meal_analysis/domain/models/similar_meal_context.dart';
import '../../../meal_analysis/domain/use_cases/find_similar_meals_use_case.dart';
import '../models/meal_details_data.dart';

final similarMealsProvider = FutureProvider.autoDispose
    .family<SimilarMealContext?, MealDetailsData>((ref, details) {
      final snapshot = details.preferredSummarySnapshot;
      if (snapshot == null) return null;
      final grams = <int, double>{};
      for (final ingredient in details.ingredients) {
        final amount = details.consumedSnapshot != null
            ? ingredient.consumedTotalGrams
            : ingredient.isExtra
            ? 0.0
            : ingredient.plannedTotalGrams;
        if (amount > 0) {
          grams[ingredient.ingredientId] =
              (grams[ingredient.ingredientId] ?? 0) + amount;
        }
      }
      return FindSimilarMealsUseCase(
        loadMeals: MealContextLocalHistoryRepository(
          ref.watch(databaseProvider),
        ).loadSimilarMeals,
      )(
        mealId: details.meal.id,
        composition: MealComposition(grams),
        asOf: details.analysisTime,
        target: MealMacroSummary(
          carbsGrams: snapshot.totalCarbsG,
          netCarbsGrams: snapshot.totalNetCarbsG,
          proteinGrams: snapshot.totalProteinG,
          fatGrams: snapshot.totalFatG,
          fiberGrams: snapshot.totalFiberG,
          totalGrams: snapshot.totalGrams,
        ),
      );
    });
