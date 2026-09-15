import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../low_treatment/data/providers/recorded_low_treatment_repository_provider.dart';
import '../../../meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import '../../domain/use_cases/load_day_analysis_history_use_case.dart';
import '../repositories/day_analysis_meal_repository.dart';

final loadDayAnalysisHistoryProvider = Provider.autoDispose((ref) {
  final glucose = ref.watch(glucoseHistoryRepositoryProvider.future);
  final statuses = ref.watch(deviceStatusHistoryRepositoryProvider.future);
  final treatments = ref.watch(treatmentsHistoryRepositoryProvider.future);
  final db = ref.watch(databaseProvider);
  final meals = DayAnalysisMealRepository(db);
  final mealHistory = MealContextLocalHistoryRepository(db);
  final lows = ref.watch(recordedLowTreatmentRepositoryProvider);
  return LoadDayAnalysisHistoryUseCase(
    now: clock.now,
    loadGlucose: (start, end) async =>
        (await glucose).fetchGlucoseBetween(start, end),
    loadStatuses: (start, end) async =>
        (await statuses).fetchDeviceStatusBetween(start, end),
    loadTreatments: (start, end) async =>
        (await treatments).fetchTreatmentsBetween(start, end),
    loadLows: lows.fetchBetween,
    loadActivities: (start, end) =>
        mealHistory.loadActivities(start, end, clock.now()),
    loadMeals: meals.loadBetween,
  );
});
