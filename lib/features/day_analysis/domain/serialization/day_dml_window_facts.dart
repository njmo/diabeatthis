import '../../../../common/analysis/dml_window_facts.dart';
import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';

Map<String, Object?> dayDmlWindowFacts({
  required DateTime start,
  required DateTime end,
  required GlucosePeriodSummary? glucose,
  required InsulinBasalSummary? basal,
  required InsulinBolusSummary? boluses,
}) => dmlWindowFacts(
  start: start,
  end: end,
  glucose: glucose,
  basal: basal,
  boluses: boluses,
);
