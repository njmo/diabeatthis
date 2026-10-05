import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/stress_events/stress_event_repository.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import '../../domain/use_cases/load_low_treatment_observation_context_use_case.dart';

/// Reads locally recorded activity plans and stress from any imported source.
final loadLowTreatmentObservationContextUseCaseProvider = Provider.autoDispose(
  (ref) => LoadLowTreatmentObservationContextUseCase(
    loadActivities: MealContextLocalHistoryRepository(
      ref.watch(databaseProvider),
    ).loadActivities,
    loadStress: ref.watch(stressEventRepositoryProvider).between,
  ),
);
