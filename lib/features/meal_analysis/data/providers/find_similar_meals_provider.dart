import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../domain/use_cases/find_similar_meals_use_case.dart';
import '../repositories/meal_context_local_history_repository.dart';

final findSimilarMealsUseCaseProvider = Provider.autoDispose(
  (ref) => FindSimilarMealsUseCase(
    loadMeals: MealContextLocalHistoryRepository(
      ref.watch(databaseProvider),
    ).loadSimilarMeals,
  ),
);
