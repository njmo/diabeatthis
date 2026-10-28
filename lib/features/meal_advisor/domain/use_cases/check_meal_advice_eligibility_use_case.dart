import 'package:clock/clock.dart';

import '../../../../core/data_sources/domain/glucose_history_repository.dart';
import '../../../../core/domain/model/glucose.dart';
import '../models/meal_advice_eligibility.dart';
import '../services/evaluate_meal_advice_eligibility.dart';

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

  MealAdviceEligibility evaluate(List<Glucose> readings, DateTime now) =>
      evaluateMealAdviceEligibility(readings, now);
}
