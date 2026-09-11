import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/providers/effective_history_source_provider.dart';
import '../../../../core/data_sources/stress_events/stress_event_repository.dart';
import '../../data/domain/use_cases/analyze_meal_use_case.dart';
import '../../data/domain/use_cases/load_low_treatments_for_meal_use_case.dart';
import '../../data/domain/use_cases/load_meal_details_use_case.dart';
import '../../data/providers/meal_before_context_provider.dart';
import '../../data/providers/similar_meal_glucose_provider.dart';
import '../../data/providers/similar_meals_provider.dart';
import '../models/meal_page_state.dart';

part 'meal_details_controller.g.dart';

@riverpod
class MealDetailsControllerNotifier extends _$MealDetailsControllerNotifier {
  @override
  Future<MealPageState> build(int mealId) async {
    final detailsUseCase = ref.read(loadMealDetailsUseCaseProvider);
    final baseDetails = await detailsUseCase.call(mealId);
    if (baseDetails.meal.isLowTreatment) {
      throw const LowTreatmentMealPageException();
    }

    ref.watch(stressEventsProvider);
    final lowTreatments = await ref.watch(
      mealLowTreatmentsForMealUseCaseProvider(mealId).future,
    );
    final details = baseDetails.copyWith(lowTreatments: lowTreatments);

    var usesLocalHistory = false;
    final analysisUseCase = ref.read(analyzeMealUseCaseProvider);
    try {
      usesLocalHistory =
          await ref.watch(effectiveHistorySourceProvider.future) ==
          HistorySource.local;
      final analysis = await analysisUseCase.call(details);
      return MealPageState(
        details: details,
        analysis: analysis,
        usesLocalHistory: usesLocalHistory,
      );
    } catch (error) {
      return MealPageState(
        details: details,
        analysisError: error.toString(),
        usesLocalHistory: usesLocalHistory,
      );
    }
  }

  Future<void> downloadHistory() async {
    final current = state.value;
    if (current == null ||
        current.isDownloadingHistory ||
        !current.details.meal.isEaten) {
      return;
    }
    state = AsyncData(current.copyWith(isDownloadingHistory: true));
    try {
      final analysis = await ref
          .read(analyzeMealUseCaseProvider)
          .call(current.details, forceCloud: true);
      if (!ref.mounted) return;
      // Rebuild active context sections from the refreshed history. Inactive
      // auto-disposed sections will load on expansion as usual.
      ref.invalidate(mealBeforeContextProvider);
      ref.invalidate(similarMealsProvider);
      ref.invalidate(similarMealGlucoseProvider);
      state = AsyncData(
        MealPageState(
          details: current.details,
          usesLocalHistory: current.usesLocalHistory,
          hasFetchedCloudHistory: true,
          analysis: analysis,
          selectedTimestamp: state.value?.selectedTimestamp,
        ),
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(
        (state.value ?? current).copyWith(isDownloadingHistory: false),
      );
      rethrow;
    }
  }

  void selectTimestamp(DateTime timestamp) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedTimestamp: timestamp));
  }

  void clearSelectedTimestamp() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearSelectedTimestamp: true));
  }
}

class LowTreatmentMealPageException implements Exception {
  const LowTreatmentMealPageException();

  @override
  String toString() {
    return lang.mealLowTreatmentsVisibleInRelatedMeal;
  }
}
