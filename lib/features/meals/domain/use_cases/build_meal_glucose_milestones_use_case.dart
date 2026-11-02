import '../../../../common/history/glucose_first_peak.dart';
import '../../../../common/history/glucose_rise_summary.dart';
import '../../../../common/history/glucose_window_summary.dart';

class BuildMealGlucoseMilestonesUseCase {
  const BuildMealGlucoseMilestonesUseCase();

  ({GlucoseFirstPeak first, GlucoseRiseSummary rise}) call(
    GlucoseWindowSummary summary,
  ) => (
    first: GlucoseFirstPeak.fromReadings(summary.readings),
    rise: GlucoseRiseSummary.fromReadings(summary.readings),
  );
}
