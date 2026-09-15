import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../../../meal_analysis/domain/models/meal_outcome_context.dart';
import 'accepted_day_summary.dart';
import 'day_analysis_history.dart';
import 'day_analysis_meal.dart';

typedef DayAnalysisWindowFacts = ({
  DateTime start,
  DateTime end,
  GlucosePeriodSummary? glucose,
  InsulinBasalSummary? basal,
  InsulinBolusSummary? boluses,
});
typedef DayAnalysisMealContext = ({
  String reference,
  DayAnalysisMeal meal,
  bool analyze,
  BeforeMealContext before,
  MealOutcomeContext outcome,
});

/// Prepared facts shared by serialization and any future analysis consumer.
class DayAnalysisContext {
  final AcceptedDaySummary accepted;
  final DayAnalysisHistory history;
  final DateTime seriesStart;
  final DayAnalysisWindowFacts? night;
  final List<DayAnalysisWindowFacts> nightIntervals;
  final List<DayAnalysisMealContext> meals;
  DayAnalysisContext({
    required this.accepted,
    required this.history,
    required this.seriesStart,
    required this.night,
    required List<DayAnalysisWindowFacts> nightIntervals,
    required List<DayAnalysisMealContext> meals,
  }) : nightIntervals = List.unmodifiable(nightIntervals),
       meals = List.unmodifiable(meals);
}
