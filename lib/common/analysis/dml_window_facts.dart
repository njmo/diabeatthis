import '../../core/domain/model/glucose.dart';
import '../history/glucose_period_summary.dart';
import '../history/insulin_basal_summary.dart';
import '../history/insulin_bolus_summary.dart';
import 'dml_timestamp.dart';

/// Shared serialization for night intervals and already-calculated meal outcomes.
Map<String, Object?> dmlWindowFacts({
  required DateTime start,
  required DateTime end,
  required GlucosePeriodSummary? glucose,
  required InsulinBasalSummary? basal,
  required InsulinBolusSummary? boluses,
  DateTime? insulinStart,
}) {
  num? finite(num? n) => n != null && n.isFinite ? n : null;
  final observedBasal = basal != null && basal.coverage > 0 ? basal : null;
  final points = <(DateTime, int), ({Glucose reading, List<String> roles})>{};
  void point(String role, Glucose? reading) {
    if (reading == null) return;
    final key = (reading.date.toUtc(), reading.sgv);
    final entry = points.putIfAbsent(key, () => (reading: reading, roles: []));
    entry.roles.add(role);
  }

  point('baseline', glucose?.window.baseline);
  point('minimum', glucose?.window.minimum);
  point('maximum', glucose?.window.peak);
  point('last_observed', glucose?.window.last);
  final ordered = points.values.toList()
    ..sort((a, b) => a.reading.date.compareTo(b.reading.date));
  final insulinFacts = <String, Object?>{
    'basal_u': finite(observedBasal?.units),
    'basal_profile_u': finite(observedBasal?.profileUnits),
    'basal_added_u': finite(observedBasal?.addedUnits),
    'basal_reduced_u': finite(observedBasal?.reducedUnits),
    'basal_coverage': finite(basal?.coverage),
    'smb_count': boluses?.otherCount,
    'smb_u': finite(boluses?.otherUnits),
    'bolus_total_u': finite(boluses?.units),
  };
  return {
    'start': dmlTimestamp(start),
    'end': dmlTimestamp(end),
    'mean_mg_dl': finite(glucose?.mean),
    'min_mg_dl': glucose?.window.minimum?.sgv,
    'max_mg_dl': glucose?.window.peak?.sgv,
    'chronological_points': glucose == null
        ? null
        : [
            for (final point in ordered)
              {
                'at': dmlTimestamp(point.reading.date),
                'mg_dl': point.reading.sgv,
                'roles': point.roles,
              },
          ],
    'cgm_observed_min': glucose?.window.observed.inMinutes,
    'cgm_samples_in_window': glucose?.window.readings.length,
    'cgm_coverage_pct': finite(glucose?.coveragePercent),
    'cgm_sampling_complete': glucose?.hasContinuousReadings,
    'has_cgm_observations': glucose == null
        ? null
        : glucose.window.observed > Duration.zero,
    'below70_min': glucose?.window.belowRange.inMinutes,
    'in70_180_min': glucose?.window.inRange.inMinutes,
    'above180_min': glucose?.window.aboveRange.inMinutes,
    if (insulinStart == null)
      ...insulinFacts
    else
      'insulin_window': {
        'start': dmlTimestamp(insulinStart),
        'end': dmlTimestamp(end),
        ...insulinFacts,
      },
  };
}
