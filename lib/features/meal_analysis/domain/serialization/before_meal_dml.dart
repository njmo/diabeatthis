import '../../../../common/analysis/dml_aaps_context.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/analysis/dml_window_facts.dart';
import '../models/before_meal_context.dart';
import 'recorded_low_treatments_dml.dart';

num? _finite(num? value) => value != null && value.isFinite ? value : null;

Map<String, Object?> beforeMealFactsDml(
  BeforeMealContext before, {
  bool includePrediction = true,
}) {
  final latest = before.latestDeviceStatus;
  return {
    ...dmlWindowFacts(
      start: before.asOf.subtract(before.windows.glucose),
      end: before.asOf,
      glucose: before.glucoseSummary,
      insulinStart: before.asOf.subtract(before.windows.insulin),
      basal: before.basal,
      boluses: before.boluses,
    ),
    'aaps': dmlAapsSnapshot(
      latest,
      cutoff: before.asOf,
      includePrediction: includePrediction,
    ),
    'failed_sources': before.failedSources.map((s) => s.name).toList(),
    'latest_cgm_mg_dl': before.latestCgm?.sgv,
    'latest_cgm_direction': before.latestCgm?.direction,
    'latest_cgm_age_min': before.latestCgm == null
        ? null
        : before.asOf.difference(before.latestCgm!.date).inSeconds / 60,
    'latest_cgm_at': before.latestCgm == null
        ? null
        : dmlTimestamp(before.latestCgm!.date),
    'fresh_cgm': before.hasFreshCgm,
    'pump_at': latest == null ? null : dmlTimestamp(latest.date),
    'iob_u': latest?.hasIob == true ? _finite(latest!.iob) : null,
    'cob_g': latest?.hasCob == true ? _finite(latest!.cob) : null,
    'activity_at': latest?.insulinActivityAt == null
        ? null
        : dmlTimestamp(latest!.insulinActivityAt!),
    'activity_u_min': latest?.hasInsulinActivity == true
        ? _finite(latest!.insulinActivity)
        : null,
    'pod_age_h': before.podAge == null ? null : before.podAge!.inMinutes / 60,
    'prior_meals': before.priorMeals == null
        ? null
        : [
            for (final m in before.priorMeals!)
              {
                'name': m.name,
                'at': dmlTimestamp(m.eatenAt),
                'net_carbs_g': _finite(m.snapshot?.totalNetCarbsG),
                'protein_g': _finite(m.snapshot?.totalProteinG),
                'fat_g': _finite(m.snapshot?.totalFatG),
              },
          ],
    'ecarbs_schedules': before.extendedCarbPlans == null
        ? null
        : [
            for (final p in before.extendedCarbPlans!)
              {
                'start': dmlTimestamp(p.treatment.createdAt),
                'end': dmlTimestamp(p.endsAt),
                'scheduled_remaining_g': _finite(p.scheduledAfterCutoffGrams),
              },
          ],
    'rescues': recordedLowTreatmentsDml(before.lowTreatments),
    'rescue_record_semantics':
        'Same-time same-amount records are retained and marked, not confirmed separate portions or proven duplicates. Their combined intake is uncertain.',
    'activity_record_semantics':
        'Activity start/end are application records. Timed activities may end automatically at the planned time; this is not verified exercise duration.',
    'activities': before.activities == null
        ? null
        : [
            for (final a in before.activities!)
              {
                'name': a.name,
                'start': dmlTimestamp(a.startedAt),
                'end': a.endedAt == null ? null : dmlTimestamp(a.endedAt!),
                'phase_at_cutoff': a.startedAt.isAfter(before.asOf)
                    ? 'upcoming'
                    : a.endedAt == null
                    ? 'started_end_unknown'
                    : 'ended',
                'planned_duration_min': a.plannedDurationMinutes,
                'configured_pre_percent': a.percentagePre,
                'configured_post_percent': a.percentagePost,
                'settings_are_current_not_historical': true,
              },
          ],
  };
}
