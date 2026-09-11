import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/glucose_window_summary.dart';
import '../../../../core/domain/model/glucose.dart';
import '../models/meal_glucose_analysis.dart';

class AnalyzeMealGlucoseUseCase {
  final Future<List<Glucose>> Function(DateTime start, DateTime end)
  loadGlucose;
  final DateTime Function() now;
  const AnalyzeMealGlucoseUseCase({
    required this.loadGlucose,
    required this.now,
  });

  Future<MealGlucoseAnalysis> call({
    required DateTime mealTime,
    required Duration window,
    required DateTime asOf,
  }) async {
    final current = now();
    final cutoff = asOf.isBefore(current) ? asOf : current;
    if (cutoff.isBefore(mealTime)) {
      throw ArgumentError.value(asOf, 'asOf', 'Must not precede the meal');
    }
    final expected = mealTime.add(window);
    final end = expected.isBefore(cutoff) ? expected : cutoff;
    final readings = await loadGlucose(
      mealTime.subtract(const Duration(minutes: 5)),
      end,
    );
    return MealGlucoseAnalysis(
      mealTime: mealTime,
      observedUntil: end,
      expectedUntil: expected,
      glucoseSummary: GlucosePeriodSummary.calculate(
        readings,
        mealTime,
        end,
        baselinePolicy: GlucoseBaselinePolicy.nearest,
      ),
    );
  }
}
