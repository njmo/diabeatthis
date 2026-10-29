import '../models/before_meal_context.dart';
import '../models/meal_ai_context.dart';
import '../use_cases/assess_meal_comparison_use_case.dart';

Map<String, Object?> mealComparisonEvidenceDml({
  required BeforeMealContext current,
  required MealAiObservation reference,
}) {
  final evidence = const AssessMealComparisonUseCase()(
    current: current,
    reference: reference,
  );
  return {
    'response_cgm_available': evidence.responseCgmAvailable,
    'response_cgm_continuous': evidence.responseCgmContinuous,
    'starting_glucose_delta_reference_minus_current_mg_dl':
        evidence.startingGlucoseDelta,
    'starting_trend_matches': evidence.startingTrendMatches,
  };
}
