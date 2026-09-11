import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../low_treatment/data/providers/recorded_low_treatment_repository_provider.dart';
import '../../domain/models/day_context.dart';
import '../../domain/use_cases/build_day_context_use_case.dart';
import '../repositories/day_local_history_repository.dart';

/// Auto-disposal prevents a completed request from replacing a refreshed page.
final dayContextProvider = dayContextForDateProvider(null);

/// Null follows today; an explicit date keeps historical requests isolated.
final dayContextForDateProvider = FutureProvider.autoDispose
    .family<DayContext, DateTime?>((ref, date) {
      final glucoseRepository = ref.watch(
        glucoseHistoryRepositoryProvider.future,
      );
      final treatmentsRepository = ref.watch(
        treatmentsHistoryRepositoryProvider.future,
      );
      final statusesRepository = ref.watch(
        deviceStatusHistoryRepositoryProvider.future,
      );
      final nightscoutRepository = ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final local = DayLocalHistoryRepository(ref.watch(databaseProvider));
      final lows = ref.watch(recordedLowTreatmentRepositoryProvider);
      return BuildDayContextUseCase(
        loadGlucose: (start, end) async =>
            (await glucoseRepository).fetchGlucoseBetween(start, end),
        loadTreatments: (start, end) async =>
            (await treatmentsRepository).fetchTreatmentsBetween(start, end),
        loadDeviceStatuses: (start, end) async =>
            (await statusesRepository).fetchDeviceStatusBetween(start, end),
        loadMeals: local.loadMeals,
        loadLowTreatments: lows.fetchBetween,
        loadActivities: local.loadActivities,
        loadSensorAge: (asOf) async {
          final repository = await nightscoutRepository;
          return withClock(
            Clock.fixed(asOf),
            repository.getLatestSensorChangeAge,
          );
        },
        loadPodAge: (asOf) async {
          final repository = await nightscoutRepository;
          return withClock(
            Clock.fixed(asOf),
            repository.getLatestInsulinChangeAge,
          );
        },
        now: clock.now,
      )(date: date);
    });
