import 'package:diabeatthis/features/meal_analysis/domain/models/meal_glucose_analysis.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_outcome_context.dart';

MealGlucoseAnalysis glucosePreview(MealOutcomeContext outcome) =>
    MealGlucoseAnalysis(
      mealTime: outcome.mealTime,
      observedUntil: outcome.observedUntil,
      expectedUntil: outcome.expectedUntil,
      glucoseSummary: outcome.glucoseSummary,
    );
