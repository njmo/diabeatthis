import 'package:clock/clock.dart';

import '../../core/data_sources/nightscout/repository/nightscout_repository.dart';
import '../../features/day_analysis/domain/models/day_context.dart';
import '../../features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'nightscout_history_repositories.dart';

/// Same day/night calculations, without local records, links, persistence or AI.
class LoadNightscoutDayContextUseCase {
  LoadNightscoutDayContextUseCase(this.nightscout, {DateTime Function()? now})
    : now = now ?? clock.now;
  final NightscoutRepository nightscout;
  final DateTime Function() now;

  Future<DayContext> call({required DateTime date}) {
    final history = NightscoutHistoryRepositories(nightscout);
    return BuildDayContextUseCase(
      loadGlucose: history.glucose.fetchGlucoseBetween,
      loadTreatments: history.treatments.fetchTreatmentsBetween,
      loadDeviceStatuses: history.deviceStatuses.fetchDeviceStatusBetween,
      loadSensorAge: (asOf) =>
          withClock(Clock.fixed(asOf), nightscout.getLatestSensorChangeAge),
      loadPodAge: (asOf) =>
          withClock(Clock.fixed(asOf), nightscout.getLatestInsulinChangeAge),
      now: now,
    )(date: date);
  }
}
