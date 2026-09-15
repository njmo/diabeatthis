import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';

/// Shared serialization for night intervals and already-calculated meal outcomes.
Map<String, Object?> dayDmlWindowFacts({
  required DateTime start,
  required DateTime end,
  required GlucosePeriodSummary? glucose,
  required InsulinBasalSummary? basal,
  required InsulinBolusSummary? boluses,
}) {
  num? finite(num? n) => n != null && n.isFinite ? n : null;
  final observedBasal = basal != null && basal.coverage > 0 ? basal : null;
  return {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'mean_mg_dl': finite(glucose?.mean),
    'min_mg_dl': glucose?.window.minimum?.sgv,
    'max_mg_dl': glucose?.window.peak?.sgv,
    'cgm_observed_min': glucose?.window.observed.inMinutes,
    'below70_min': glucose?.window.belowRange.inMinutes,
    'in70_180_min': glucose?.window.inRange.inMinutes,
    'above180_min': glucose?.window.aboveRange.inMinutes,
    'basal_u': finite(observedBasal?.units),
    'basal_profile_u': finite(observedBasal?.profileUnits),
    'basal_added_u': finite(observedBasal?.addedUnits),
    'basal_reduced_u': finite(observedBasal?.reducedUnits),
    'basal_coverage': finite(basal?.coverage),
    'smb_count': boluses?.otherCount,
    'smb_u': finite(boluses?.otherUnits),
    'bolus_total_u': finite(boluses?.units),
  };
}
