import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/async/async_task_pool.dart';
import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../meal_analysis/domain/models/meal_glucose_analysis.dart';
import '../../../meal_analysis/domain/use_cases/analyze_meal_glucose_use_case.dart';
import '../domain/use_cases/load_meal_details_use_case.dart';

final similarMealAnalysisPoolProvider = Provider((ref) => AsyncTaskPool(2));

final similarMealGlucoseProvider = FutureProvider.autoDispose
    .family<MealGlucoseAnalysis?, ({int mealId, DateTime asOf})>((
      ref,
      request,
    ) {
      final pool = ref.watch(similarMealAnalysisPoolProvider);
      final load = ref.watch(loadMealDetailsUseCaseProvider);
      final glucose = ref.watch(glucoseHistoryRepositoryProvider.future);
      return pool.run(() async {
        if (!ref.mounted) return null;
        final details = await load(request.mealId);
        if (!ref.mounted) return null;
        if (!details.meal.isEaten) return null;
        final repository = await glucose;
        if (!ref.mounted) return null;
        return AnalyzeMealGlucoseUseCase(
          loadGlucose: repository.fetchGlucoseBetween,
          now: clock.now,
        )(
          mealTime: details.analysisTime,
          window: details.observationWindow,
          asOf: request.asOf,
        );
      });
    });
