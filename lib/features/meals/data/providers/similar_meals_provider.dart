import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meal_analysis/data/providers/find_similar_meals_provider.dart';
import '../../../meal_analysis/domain/models/similar_meal_context.dart';
import '../mappers/similar_meal_query_mapper.dart';
import '../models/meal_details_data.dart';

final similarMealsProvider = FutureProvider.autoDispose
    .family<SimilarMealContext?, MealDetailsData>((ref, details) {
      final query = const SimilarMealQueryMapper().map(details);
      if (query == null) return null;
      return ref.watch(findSimilarMealsUseCaseProvider)(
        mealId: query.mealId,
        asOf: query.asOf,
        target: query.target,
        composition: query.composition,
      );
    });
