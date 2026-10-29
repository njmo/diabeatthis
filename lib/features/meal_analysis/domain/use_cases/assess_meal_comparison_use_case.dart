import '../models/before_meal_context.dart';
import '../models/meal_ai_context.dart';

typedef MealComparisonEvidence = ({
  bool responseCgmAvailable,
  bool responseCgmContinuous,
  int? startingGlucoseDelta,
  bool? startingTrendMatches,
});

/// Describes evidence separately from recipe similarity; does not rank meals
/// or claim that similar starting conditions establish a causal comparison.
class AssessMealComparisonUseCase {
  const AssessMealComparisonUseCase();

  MealComparisonEvidence call({
    required BeforeMealContext current,
    required MealAiObservation reference,
  }) {
    final outcome = reference.outcome;
    final before = reference.before;
    final freshStarts = current.hasFreshCgm && before.hasFreshCgm;
    const directions = {
      'DoubleDown',
      'SingleDown',
      'FortyFiveDown',
      'Flat',
      'FortyFiveUp',
      'SingleUp',
      'DoubleUp',
    };
    final currentTrend = current.latestCgm?.direction;
    final referenceTrend = before.latestCgm?.direction;
    return (
      responseCgmAvailable:
          outcome != null &&
          outcome.glucoseSummary.window.readings.isNotEmpty &&
          outcome.glucoseSummary.window.observed > Duration.zero,
      responseCgmContinuous:
          outcome != null &&
          outcome.isTimeWindowComplete &&
          outcome.glucoseSummary.hasContinuousReadings,
      startingGlucoseDelta: freshStarts
          ? before.latestCgm!.sgv - current.latestCgm!.sgv
          : null,
      startingTrendMatches:
          freshStarts &&
              directions.contains(currentTrend) &&
              directions.contains(referenceTrend)
          ? currentTrend == referenceTrend
          : null,
    );
  }
}
