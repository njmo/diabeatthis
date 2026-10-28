import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meal_analysis/data/providers/find_similar_meals_provider.dart';
import '../../../meal_analysis/data/providers/meal_ai_provider.dart';
import '../../../meals/data/domain/use_cases/load_meal_details_use_case.dart';
import '../../../meals/data/mappers/meal_advisor_target_mapper.dart';
import '../../domain/use_cases/build_meal_advisor_context_use_case.dart';

/// Creating this use case does not initialize optional repositories or start reads.
final buildMealAdvisorContextUseCaseProvider = Provider(
  (ref) => BuildMealAdvisorContextUseCase(
    now: clock.now,
    loadTarget: (before) async {
      final mealId = before.mealId;
      final macros = before.macros;
      if (mealId == null || macros == null) {
        throw StateError('Missing planned meal');
      }
      final load = ref.read(loadMealDetailsUseCaseProvider);
      return const MealAdvisorTargetMapper().map(
        await load(mealId),
        macros,
        before.asOf,
      );
    },
    findSimilar: (target, asOf) async =>
        ref.read(findSimilarMealsUseCaseProvider)(
          mealId: target.mealId,
          asOf: asOf,
          target: target.macros,
          composition: target.composition,
        ),
    loadHistorical: (id, cutoff) async =>
        ref.read(buildMealAiContextUseCaseProvider).loadObservation(id, cutoff),
  ),
);
