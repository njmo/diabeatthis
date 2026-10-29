import '../../../../common/analysis/dml_aaps_context.dart';
import '../../../../common/analysis/dml_time_blocks.dart';
import '../../../../common/analysis/dml_timestamp.dart';
import '../../../../common/analysis/dml_treatment_context.dart';
import '../../../../common/analysis/dml_window_facts.dart';
import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/treat.dart';
import '../models/before_meal_context.dart';
import '../models/meal_ai_context.dart';
import '../models/meal_ai_facts.dart';
import 'before_meal_dml.dart';
import 'meal_record_evidence_dml.dart';
import 'recorded_low_treatments_dml.dart';

export 'before_meal_dml.dart' show beforeMealFactsDml;

num? _finite(num? value) => value != null && value.isFinite ? value : null;
Map<String, Object?> _mealFacts(MealAiFacts meal) => {
  'name': meal.name,
  'eaten_at': dmlTimestamp(meal.eatenAt),
  'ended_at': meal.endedAt == null ? null : dmlTimestamp(meal.endedAt!),
  'wait_min': meal.wait == null ? null : meal.wait!.inSeconds / 60,
  'observation_min': meal.window.inMinutes,
  'macro_source': meal.macroSource,
  'net_carbs_g': _finite(meal.macros?.netCarbsGrams),
  'protein_g': _finite(meal.macros?.proteinGrams),
  'fat_g': _finite(meal.macros?.fatGrams),
  'fiber_g': _finite(meal.macros?.fiberGrams),
  'mass_g': _finite(meal.macros?.totalGrams),
  'ingredients': [
    for (final ingredient in meal.ingredients)
      [ingredient.name, _finite(ingredient.grams)],
  ],
  'stage_columns': ['time', 'status'],
  'stage_blocks': dmlTimeBlocks([
    for (final stage in meal.stages) (at: stage.at, values: [stage.status]),
  ]),
};

void appendMealObservationDml(
  void Function(String, Map<String, Object?>) add,
  String prefix,
  MealAiObservation observed,
) {
  final meal = observed.meal;
  final before = observed.before;
  final outcome = observed.outcome;
  add(prefix, _mealFacts(meal));
  add(
    '${prefix}_record_evidence',
    mealRecordEvidenceDml(
      mealId: meal.mealId,
      evidence: meal.evidence,
      mealTime: meal.eatenAt,
      workflowWait: meal.wait,
      before: before,
      outcome: outcome,
    ),
  );
  final latest = before.latestDeviceStatus;
  add('${prefix}_before', beforeMealFactsDml(before));
  final start = before.asOf.subtract(before.windows.glucose);
  final end = outcome?.observedUntil ?? before.asOf;
  final glucose = [...?before.glucose, ...?outcome?.glucose];
  // The outcome already includes a full treatment lead-in; prefer that single fetch.
  final treatments = (outcome?.treatments ?? before.treatments ?? [])
      .where(
        (t) => t.isValid && t.createdAt != null && !t.createdAt!.isAfter(end),
      )
      .toList();
  for (final section in dmlTreatmentContext(
    treatments: before.treatments == null && outcome == null
        ? null
        : treatments,
    glucose: before.glucose == null && outcome == null ? null : glucose,
    start: start,
    historyStart:
        outcome?.treatmentHistoryStart ??
        before.asOf.subtract(
          before.windows.meals > before.windows.insulin
              ? before.windows.meals
              : before.windows.insulin,
        ),
    end: end,
  )) {
    add('${prefix}_${section.id}', section.facts);
  }
  final byTime = {for (final g in glucose) g.date.toUtc(): g};
  add('${prefix}_cgm', {
    'columns': ['time', 'mg_dl'],
    'blocks': before.glucose == null && outcome == null
        ? null
        : dmlTimeBlocks([
            for (final g in byTime.values)
              if (!g.date.isBefore(start) && !g.date.isAfter(end))
                (at: g.date, values: [g.sgv]),
          ]),
  });
  final statuses = <DateTime, DeviceStatus>{
    if (latest != null) latest.date.toUtc(): latest,
    for (final s in outcome?.deviceStatuses ?? []) s.date.toUtc(): s,
  }.values;
  add('${prefix}_pump', {
    'columns': [
      'time',
      'iob_u',
      'cob_g',
      'activity_u_min',
      'activity_at',
      'basal_at',
      'profile_u_h',
      'temp_u_h',
    ],
    'blocks':
        before.failedSources.contains(BeforeMealSource.deviceStatus) &&
            outcome == null
        ? null
        : dmlTimeBlocks([
            for (final s in statuses)
              (
                at: s.date,
                values: [
                  s.hasIob ? _finite(s.iob) : null,
                  s.hasCob ? _finite(s.cob) : null,
                  s.hasInsulinActivity ? _finite(s.insulinActivity) : null,
                  s.insulinActivityAt,
                  s.basalObservedAt,
                  s.basalObservedAt == null ? null : _finite(s.baseBasalRate),
                  _finite(s.tempBasalAbsoluteRate),
                ],
              ),
          ]),
  });
  add(
    '${prefix}_aaps',
    dmlAapsContext(
      statuses:
          before.failedSources.contains(BeforeMealSource.deviceStatus) &&
              outcome == null
          ? null
          : statuses.toList(),
      treatments: before.treatments == null && outcome == null
          ? null
          : treatments,
      start: before.asOf.subtract(before.windows.insulin),
      end: end,
      predictionAnchors: [if (latest != null) latest],
    ),
  );
  final grouping = BolusWizardGrouping(treatments);
  add('${prefix}_intake_insulin', {
    'start': dmlTimestamp(before.asOf.subtract(before.windows.insulin)),
    'columns': ['time', 'kind', 'carbs_g', 'insulin_u'],
    'blocks': before.treatments == null && outcome == null
        ? null
        : dmlTimeBlocks([
            for (final t in treatments)
              if (!t.createdAt!.isBefore(
                    before.asOf.subtract(before.windows.insulin),
                  ) &&
                  !grouping.isRelated(t))
                if (t is BolusWizard)
                  (
                    at: t.createdAt,
                    values: ['wizard', _finite(t.carbs), _finite(t.insulin)],
                  )
                else if (t is Treat)
                  (at: t.createdAt, values: ['carbs', t.carbs, null])
                else if (t is ManualBolus)
                  (
                    at: t.createdAt,
                    values: ['manual', null, _finite(t.insulin)],
                  )
                else if (t is CorrectionBolus)
                  (at: t.createdAt, values: ['smb', null, _finite(t.insulin)]),
          ]),
  });
  add(
    '${prefix}_outcome',
    outcome == null
        ? {'available': false}
        : {
            ...dmlWindowFacts(
              start: outcome.mealTime,
              end: outcome.observedUntil,
              glucose: outcome.glucoseSummary,
              basal: outcome.basal,
              boluses: outcome.boluses,
            ),
            'available': true,
            'expected_until': dmlTimestamp(outcome.expectedUntil),
            'window_complete': outcome.isTimeWindowComplete,
            'subsequent_meals': outcome.subsequentMeals == null
                ? null
                : [
                    for (final m in outcome.subsequentMeals!)
                      {'name': m.name, 'at': dmlTimestamp(m.eatenAt)},
                  ],
            'rescues': recordedLowTreatmentsDml(outcome.lowTreatments),
            'activities': [
              for (final a in outcome.activities)
                {
                  'name': a.name,
                  'start': dmlTimestamp(a.startedAt),
                  'end': a.endedAt == null ? null : dmlTimestamp(a.endedAt!),
                  'intensity': a.intensity,
                },
            ],
            'ecarbs_overlap': [
              for (final e in outcome.extendedCarbs)
                {
                  'start': dmlTimestamp(e.overlapStart),
                  'end': dmlTimestamp(e.overlapEnd),
                  'scheduled_g': _finite(e.scheduledGrams),
                  'started_before_meal': e.startedBeforeMeal,
                },
            ],
          },
  );
}
