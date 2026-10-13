import '../../../../common/analysis/dml_treatment_context.dart';
import '../models/day_analysis_history.dart';

typedef DayDmlContextSection = DmlContextSection;
List<DayDmlContextSection> dayDmlTreatmentContext(
  DayAnalysisHistory history,
  DateTime start,
) => dmlTreatmentContext(
  treatments: history.treatments,
  glucose: history.glucose,
  start: start,
  historyStart: history.start,
  end: history.end,
);
