import 'package:clock/clock.dart';

import '../../../../core/data_sources/domain/glucose_history_repository.dart';
import '../../../../core/domain/model/glucose.dart';
import '../models/meal_advice_eligibility.dart';

class CheckMealAdviceEligibilityUseCase {
  final Future<GlucoseHistoryRepository> Function() loadRepository;
  final Duration timeout;

  const CheckMealAdviceEligibilityUseCase({
    required this.loadRepository,
    this.timeout = const Duration(seconds: 10),
  });

  Future<MealAdviceEligibility> call() async {
    try {
      final readings = await _loadReadings().timeout(timeout);
      // Use completion time: network latency must not make old CGM seem fresh.
      return evaluate(readings, clock.now());
    } on Exception {
      return MealAdviceEligibility.historyUnavailable;
    }
  }

  Future<List<Glucose>> _loadReadings() async {
    final repository = await loadRepository();
    final now = clock.now();
    return repository.fetchGlucoseBetween(
      now.subtract(const Duration(minutes: 30)),
      now,
    );
  }

  MealAdviceEligibility evaluate(List<Glucose> readings, DateTime now) {
    final unique = <DateTime, Glucose>{};
    for (final reading in readings) {
      if (reading.type == GlucoseType.cgm &&
          reading.sgv > 0 &&
          !reading.date.isAfter(now)) {
        unique[reading.date] = reading;
      }
    }
    final ordered = unique.keys.toList()..sort();
    if (ordered.length < 3) return MealAdviceEligibility.insufficientReadings;
    if (now.difference(ordered.last) >= const Duration(minutes: 10)) {
      return MealAdviceEligibility.staleReadings;
    }
    final recent = ordered.sublist(ordered.length - 3);
    for (var i = 1; i < recent.length; i++) {
      final interval = recent[i].difference(recent[i - 1]);
      // A five-minute CGM cadence with one minute of timestamp tolerance.
      if (interval < const Duration(minutes: 4) ||
          interval > const Duration(minutes: 6)) {
        return MealAdviceEligibility.discontinuousReadings;
      }
    }
    return MealAdviceEligibility.available;
  }
}
