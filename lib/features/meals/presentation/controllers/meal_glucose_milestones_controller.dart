import '../../../../common/history/glucose_first_peak.dart';
import '../../../../common/history/glucose_rise_summary.dart';
import '../../../../common/history/glucose_window_summary.dart';
import '../../domain/use_cases/build_meal_glucose_milestones_use_case.dart';

class MealGlucoseMilestonesController {
  const MealGlucoseMilestonesController({
    this.buildMilestones = const BuildMealGlucoseMilestonesUseCase(),
  });
  final BuildMealGlucoseMilestonesUseCase buildMilestones;

  ({GlucoseFirstPeak first, GlucoseRiseSummary rise}) build(
    GlucoseWindowSummary summary,
  ) => buildMilestones(summary);
}
