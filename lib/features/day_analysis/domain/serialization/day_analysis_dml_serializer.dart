import 'dart:convert';

import '../../../../core/domain/model/correction_bolus.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../models/day_analysis_context.dart';
import '../models/day_dml_document.dart';
import '../use_cases/build_day_dml_use_case.dart';
import 'day_dml_time_blocks.dart';
import 'day_dml_treatment_context.dart';
import 'day_dml_window_facts.dart';

/// Formats prepared facts only. No history reads, calculations or UI labels.
DayDmlDocument serializeDayAnalysisContext(DayAnalysisContext context) {
  final accepted = context.accepted;
  final history = context.history;
  final base = const BuildDayDmlUseCase()(accepted, hasEventHistory: true);
  final text = StringBuffer(base.text);
  final ids = {...base.evidenceIds};
  final mealReferences = <String, ({String name, DateTime at})>{};
  void add(String kind, String id, Map<String, Object?> data) {
    ids.add(id);
    text.writeln('$kind ${jsonEncode({'id': id, ...data})}');
  }

  String at(DateTime t) => t.toUtc().toIso8601String();
  num? finite(num? value) => value != null && value.isFinite ? value : null;
  final seriesStart = context.seriesStart;
  bool inSeries(DateTime t) =>
      !t.isBefore(seriesStart) && !t.isAfter(history.end);
  final glucose = {
    for (final g in history.glucose ?? [])
      if (g.type == GlucoseType.cgm && g.sgv > 0 && inSeries(g.date)) g.date: g,
  }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  final statuses = {
    for (final s in history.statuses ?? [])
      if (inSeries(s.date)) s.date: s,
  }.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  final treatments =
      [
          ...?history.treatments,
        ].where((t) => t.isValid && t.createdAt != null).toList()
        ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  add('HISTORY', 'history', {
    'built_at': at(history.builtAt),
    'start': at(history.start),
    'end': at(history.end),
    'source': 'current_history_reconstruction',
    'failed_sources': history.failures.toList()..sort(),
    'unavailable_meal_count': history.failedMealIds.length,
    'accepted_aggregates_are_not_recomputed': true,
    'series_start': at(seriesStart),
    'timestamps':
        'UTC for standalone facts; local HH:mm within dated series blocks',
    'local_clock_source': 'device_timezone_at_generation',
    'local_offset_minutes_at_series_start': seriesStart
        .toLocal()
        .timeZoneOffset
        .inMinutes,
    'local_offset_minutes_at_end': history.end
        .toLocal()
        .timeZoneOffset
        .inMinutes,
  });
  for (final section in dayDmlTreatmentContext(history, seriesStart)) {
    add(section.kind, section.id, section.facts);
  }
  add('CGM', 'cgm', {
    'columns': ['time', 'mg_dl'],
    'blocks': dayDmlTimeBlocks(
      history.glucose == null
          ? null
          : [
              for (final g in glucose) (at: g.date, values: [g.sgv]),
            ],
    ),
  });
  add('PUMP', 'pump', {
    'columns': [
      'time',
      'iob_u',
      'cob_g',
      'activity_u_min',
      'activity_at',
      'basal_observed_at',
      'profile_u_h',
      'temp_u_h',
      'temp_remaining_min',
    ],
    'blocks': dayDmlTimeBlocks(
      history.statuses == null
          ? null
          : [
              for (final s in statuses)
                (
                  at: s.date,
                  values: [
                    s.hasIob ? finite(s.iob) : null,
                    s.hasCob ? finite(s.cob) : null,
                    s.hasInsulinActivity ? finite(s.insulinActivity) : null,
                    s.insulinActivityAt,
                    s.basalObservedAt,
                    s.basalObservedAt == null ? null : finite(s.baseBasalRate),
                    finite(s.tempBasalAbsoluteRate),
                    s.tempBasalRemainingMinutes,
                  ],
                ),
            ],
    ),
  });
  add('BOLUSES', 'boluses', {
    'columns': ['time', 'kind', 'units'],
    'blocks': dayDmlTimeBlocks(
      history.treatments == null
          ? null
          : [
              for (final t in treatments)
                if (inSeries(t.createdAt!) &&
                    t is ManualBolus &&
                    t.insulin > 0 &&
                    t.insulin.isFinite)
                  (at: t.createdAt, values: ['manual', t.insulin])
                else if (inSeries(t.createdAt!) &&
                    t is CorrectionBolus &&
                    t.insulin > 0 &&
                    t.insulin.isFinite)
                  (at: t.createdAt, values: ['smb', t.insulin]),
            ],
    ),
  });
  add('ECARBS', 'ecarbs', {
    'columns': ['start', 'carbs_g', 'duration_min'],
    'blocks': dayDmlTimeBlocks(
      history.treatments == null
          ? null
          : [
              for (final t in treatments.whereType<ExtendedCarb>())
                if (t.createdAt
                    .add(Duration(milliseconds: t.duration))
                    .isAfter(seriesStart))
                  (at: t.createdAt, values: [t.carbs, t.duration / 60000]),
            ],
    ),
  });
  add('RESCUE_CARBS', 'rescues', {
    'columns': ['time', 'net_carbs_g', 'reason'],
    'blocks': dayDmlTimeBlocks(
      history.lows == null
          ? null
          : [
              for (final low in history.lows!)
                if (inSeries(low.eatenAt))
                  (
                    at: low.eatenAt,
                    values: [finite(low.netCarbsGrams), low.reason?.name],
                  ),
            ],
    ),
  });
  add('ACTIVITY_EVENTS', 'activity_events', {
    'columns': ['start', 'end', 'name'],
    'blocks': dayDmlTimeBlocks(
      history.activities == null
          ? null
          : [
              for (final a in history.activities!)
                if ((a.endedAt ?? history.end).isAfter(seriesStart) &&
                    !a.startedAt.isAfter(history.end))
                  (at: a.startedAt, values: [a.endedAt, a.name]),
            ],
    ),
  });

  Map<String, Object?> window(DayAnalysisWindowFacts facts) =>
      dayDmlWindowFacts(
        start: facts.start,
        end: facts.end,
        glucose: facts.glucose,
        basal: facts.basal,
        boluses: facts.boluses,
      );
  if (context.night != null) {
    add('NIGHT_COURSE', 'night_course', {
      ...window(context.night!),
      'intervals': [
        for (final interval in context.nightIntervals) window(interval),
      ],
    });
  }
  for (final item in context.meals) {
    final meal = item.meal;
    final id = item.reference;
    final inDay = item.analyze;
    final before = item.before;
    final outcome = item.outcome;
    if (inDay) mealReferences[id] = (name: meal.name, at: meal.eatenAt);
    final macro = meal.macros;
    add('MEAL', id, {
      'analyze': inDay,
      'name': meal.name,
      'eaten_at': at(meal.eatenAt),
      'eating_ended_at': meal.eatingEndedAt == null
          ? null
          : at(meal.eatingEndedAt!),
      'recorded_wait_min': meal.wait?.inMinutes,
      'macro_source': meal.macroSource,
      'macros': macro == null
          ? null
          : {
              'net_carbs_g': finite(macro.netCarbsGrams),
              'fat_g': finite(macro.fatGrams),
              'protein_g': finite(macro.proteinGrams),
            },
      'ingredients': [
        for (final item in meal.ingredients)
          {'name': item.name, 'grams': finite(item.grams)},
      ],
      'recorded_stages': [
        for (final stage in meal.stages)
          {'at': at(stage.at), 'status': stage.status},
      ],
      'before': {
        'as_of': at(before.asOf),
        'mean_mg_dl': finite(before.glucoseSummary?.mean),
        'latest_iob_u': before.latestDeviceStatus?.hasIob == true
            ? finite(before.latestDeviceStatus?.iob)
            : null,
        'latest_cob_g': before.latestDeviceStatus?.hasCob == true
            ? finite(before.latestDeviceStatus?.cob)
            : null,
        'device_status_at': before.latestDeviceStatus == null
            ? null
            : at(before.latestDeviceStatus!.date),
        'active_ecarbs': before.extendedCarbPlans == null
            ? null
            : [
                for (final plan in before.extendedCarbPlans!)
                  {
                    'start': at(plan.treatment.createdAt),
                    'end': at(plan.endsAt),
                    'scheduled_remaining_g': finite(
                      plan.scheduledAfterCutoffGrams,
                    ),
                  },
              ],
        'failed_sources': before.failedSources.map((s) => s.name).toList()
          ..sort(),
      },
      'outcome': {
        ...dayDmlWindowFacts(
          start: meal.eatenAt,
          end: outcome.observedUntil,
          glucose: history.glucose == null ? null : outcome.glucoseSummary,
          basal: history.statuses == null ? null : outcome.basal,
          boluses: history.treatments == null ? null : outcome.boluses,
        ),
        'expected_until': at(outcome.expectedUntil),
        'complete_window': outcome.isTimeWindowComplete,
        'start_mg_dl': history.glucose == null
            ? null
            : outcome.glucoseSummary.window.baseline?.sgv,
        'peak_at': outcome.glucoseSummary.window.peak == null
            ? null
            : at(outcome.glucoseSummary.window.peak!.date),
        'ecarbs_overlap': history.treatments == null
            ? null
            : [
                for (final overlap in outcome.extendedCarbs)
                  {
                    'start': at(overlap.overlapStart),
                    'end': at(overlap.overlapEnd),
                    'scheduled_g': finite(overlap.scheduledGrams),
                    'started_before_meal': overlap.startedBeforeMeal,
                  },
              ],
        'other_meals_at': history.meals == null
            ? null
            : [for (final m in outcome.subsequentMeals ?? []) at(m.eatenAt)],
      },
    });
  }
  return DayDmlDocument(
    text: text.toString(),
    evidenceIds: ids,
    meals: mealReferences,
  );
}
