import 'package:clock/clock.dart';

import '../../../../core/data_sources/domain/device_status_history_repository.dart';
import '../../../../core/domain/model/device_status.dart';
import '../models/meal_advice_eligibility.dart';
import '../models/resolved_meal_advisor_device_status.dart';
import 'check_meal_advisor_device_status_use_case.dart';

class ResolveMealAdvisorDeviceStatusUseCase {
  const ResolveMealAdvisorDeviceStatusUseCase({
    required this.loadRepository,
    required this.readCurrentStatus,
    this.checkStatus = const CheckMealAdvisorDeviceStatusUseCase(),
    this.timeout = const Duration(seconds: 10),
  });

  final Future<DeviceStatusHistoryRepository> Function() loadRepository;
  final DeviceStatus? Function() readCurrentStatus;
  final CheckMealAdvisorDeviceStatusUseCase checkStatus;
  final Duration timeout;

  Future<ResolvedMealAdvisorDeviceStatus> call() async {
    final initial = readCurrentStatus();
    if (initial != null &&
        checkStatus(initial) == MealAdviceEligibility.available) {
      return ResolvedMealAdvisorDeviceStatus(
        status: initial,
        eligibility: MealAdviceEligibility.available,
      );
    }

    DeviceStatus? history;
    var historyFailed = false;
    try {
      history = await _loadLatestHistory().timeout(timeout);
    } catch (_) {
      historyFailed = true;
    }

    // Live synchronization may finish during the history request. Validate both
    // at completion, so loading latency cannot make an old snapshot usable.
    final current = readCurrentStatus();
    DeviceStatus? usable;
    for (final candidate in [current, history]) {
      if (candidate != null &&
          checkStatus(candidate) == MealAdviceEligibility.available &&
          (usable == null || candidate.date.isAfter(usable.date))) {
        usable = candidate;
      }
    }
    if (usable != null) {
      return ResolvedMealAdvisorDeviceStatus(
        status: usable,
        eligibility: MealAdviceEligibility.available,
      );
    }
    if (historyFailed) {
      return const ResolvedMealAdvisorDeviceStatus(
        eligibility: MealAdviceEligibility.historyUnavailable,
      );
    }

    final latest =
        history != null &&
            (current == null || history.date.isAfter(current.date))
        ? history
        : current;
    return ResolvedMealAdvisorDeviceStatus(
      eligibility: latest == null
          ? MealAdviceEligibility.missingDeviceStatus
          : checkStatus(latest),
    );
  }

  Future<DeviceStatus?> _loadLatestHistory() async {
    final repository = await loadRepository();
    return repository.fetchLastDeviceStatusBefore(clock.now());
  }
}
