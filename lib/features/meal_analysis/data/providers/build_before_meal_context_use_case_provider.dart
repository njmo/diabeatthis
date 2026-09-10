import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/data_sources/providers/on_demand_history_repositories_provider.dart';
import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../low_treatment/data/providers/recorded_low_treatment_repository_provider.dart';
import '../../domain/use_cases/build_before_meal_context_use_case.dart';
import '../repositories/meal_context_local_history_repository.dart';

/// History is fetched on invocation. The caller owns the context cutoff.
final buildBeforeMealContextUseCaseProvider = Provider.autoDispose
    .family<BuildBeforeMealContextUseCase, bool>((ref, forceCloud) {
      final remote = forceCloud
          ? ref.watch(onDemandHistoryRepositoriesProvider.future)
          : null;
      final glucose = remote == null
          ? ref.watch(glucoseHistoryRepositoryProvider.future)
          : remote.then((r) => r.glucose);
      final statuses = remote == null
          ? ref.watch(deviceStatusHistoryRepositoryProvider.future)
          : remote.then((r) => r.deviceStatuses);
      final treatments = remote == null
          ? ref.watch(treatmentsHistoryRepositoryProvider.future)
          : remote.then((r) => r.treatments);
      final local = MealContextLocalHistoryRepository(
        ref.watch(databaseProvider),
      );
      final lows = ref.watch(recordedLowTreatmentRepositoryProvider);
      final nightscout = ref.watch(nightscoutRepositoryProvider.future);
      return BuildBeforeMealContextUseCase(
        loadGlucose: (start, end) async =>
            (await glucose).fetchGlucoseBetween(start, end),
        loadDeviceStatuses: (start, end) async =>
            (await statuses).fetchDeviceStatusBetween(start, end),
        loadTreatments: (start, end) async =>
            (await treatments).fetchTreatmentsBetween(start, end),
        loadMeals: local.loadMeals,
        loadLowTreatments: lows.fetchBetween,
        loadActivities: local.loadActivities,
        loadPodAge: (cutoff) async => withClock(
          Clock.fixed(cutoff),
          (await nightscout).getLatestInsulinChangeAge,
        ),
        now: clock.now,
      );
    });
