import '../../../../common/analysis/dml_aaps_context.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/analysis/dml_window_facts.dart';
import '../models/before_meal_context.dart';
import 'recorded_low_treatments_dml.dart';

num? _finite(num? value) => value != null && value.isFinite ? value : null;

Map<String, Object?> beforeMealFactsDml(
  BeforeMealContext before, {
  bool includePrediction = true,
  String Function(Map<String, Object?>)? registerPrediction,
  Map<String, Object?>? sharedEvents,
}) {
  final latest = before.latestDeviceStatus;
  final glucoseWindow = dmlWindowFacts(
    start: before.asOf.subtract(before.windows.glucose),
    end: before.asOf,
    glucose: before.glucoseSummary,
    insulinStart: before.asOf.subtract(before.windows.insulin),
    basal: before.basal,
    boluses: before.boluses,
  );
  final insulinWindow = glucoseWindow.remove('insulin_window');
  return {
    'as_of': dmlTimestamp(before.asOf),
    'aaps': dmlAapsSnapshot(
      latest,
      cutoff: before.asOf,
      includePrediction: includePrediction,
      registerPrediction: registerPrediction,
    ),
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
    'glucose_window': glucoseWindow,
    'insulin_window': insulinWindow,
    'events': {
      'meal_window_start': dmlTimestamp(
        before.asOf.subtract(before.windows.meals),
      ),
      'meal_window_end': dmlTimestamp(before.asOf),
      'activity_window_start': dmlTimestamp(
        before.asOf.subtract(before.windows.activities),
      ),
      'activity_window_end': dmlTimestamp(
        before.asOf.add(before.windows.upcomingActivities),
      ),
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
      if (sharedEvents != null)
        ...sharedEvents
      else ...{
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
        'rescues': recordedLowTreatmentsDml(before.lowTreatments),
      },
    },
    'quality': {
      'failed_sources': before.failedSources.map((s) => s.name).toList()
        ..sort(),
      'food_diary_completeness': 'unknown',
      'treatment_history_completeness': 'unknown',
    },
  };
}
