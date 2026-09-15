import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../meal_analysis/domain/models/meal_activity_observation.dart';
import '../../../meal_analysis/domain/models/recorded_meal_context.dart';
import '../../../meal_analysis/domain/use_cases/build_before_meal_context_use_case.dart';
import '../../../meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import '../models/accepted_day_summary.dart';
import '../models/day_analysis_context.dart';
import '../models/day_analysis_history.dart';

class BuildDayAnalysisContextUseCase {
  const BuildDayAnalysisContextUseCase();
  Future<DayAnalysisContext> call(
    AcceptedDaySummary accepted,
    DayAnalysisHistory history,
  ) async {
    final day = accepted.snapshot;
    final dayStart = DateTime.parse(
      '${day.dayKey}T00:00:00Z',
    ).subtract(Duration(minutes: day.utcOffsetMinutes));
    final meals = [...?history.meals]
      ..sort((a, b) => a.eatenAt.compareTo(b.eatenAt));
    final first = day.nightStart != null && day.nightStart!.isBefore(dayStart)
        ? day.nightStart!
        : dayStart;
    final lead = meals.where((meal) => meal.eatenAt.isBefore(first)).lastOrNull;
    final seriesStart =
        lead?.eatenAt ?? first.subtract(const Duration(hours: 6));
    final treatments = [
      ...?history.treatments,
    ].where((t) => t.isValid && t.createdAt != null).toList();
    DayAnalysisWindowFacts window(DateTime start, DateTime end) => (
      start: start,
      end: end,
      glucose: history.glucose == null
          ? null
          : GlucosePeriodSummary.calculate(history.glucose!, start, end),
      basal: history.statuses == null
          ? null
          : InsulinBasalSummary.calculate(history.statuses!, start, end),
      boluses: history.treatments == null
          ? null
          : InsulinBolusSummary.fromTreatments(
              treatments: treatments.where((t) => t.createdAt!.isBefore(end)),
              start: start,
              end: end,
            ),
    );
    DayAnalysisWindowFacts? night;
    final intervals = <DayAnalysisWindowFacts>[];
    if (day.nightStart != null && day.nightEnd != null) {
      final start = day.nightStart!;
      final end = day.nightEnd!.isAfter(history.end)
          ? history.end
          : day.nightEnd!;
      if (end.isAfter(start)) {
        night = window(start, end);
        for (
          var at = start;
          at.isBefore(end);
          at = at.add(const Duration(hours: 1))
        ) {
          final next = at.add(const Duration(hours: 1));
          intervals.add(window(at, next.isAfter(end) ? end : next));
        }
      }
    }
    final results = <DayAnalysisMealContext>[];
    final recorded = [
      for (final m in meals)
        RecordedMealContext(
          mealId: m.id,
          name: m.name,
          eatenAt: m.eatenAt,
          snapshot: null,
        ),
    ];
    final beforeBuilder = BuildBeforeMealContextUseCase(
      now: () => history.builtAt,
      loadGlucose: (s, e) async =>
          history.glucose ?? (throw StateError('Missing CGM')),
      loadDeviceStatuses: (s, e) async =>
          history.statuses ?? (throw StateError('Missing pump history')),
      loadTreatments: (s, e) async =>
          history.treatments ?? (throw StateError('Missing treatments')),
      loadMeals: (s, e, id) async =>
          history.meals == null ? throw StateError('Missing meals') : recorded,
      loadLowTreatments: (s, e) async =>
          history.lows ?? (throw StateError('Missing rescue carbs')),
      loadActivities: (s, e, c) async =>
          history.activities ?? (throw StateError('Missing activities')),
      loadPodAge: (_) async => null,
    );
    var index = 0;
    for (final meal in meals.where(
      (m) =>
          m == lead ||
          (!m.eatenAt.isBefore(first) && !m.eatenAt.isAfter(history.end)),
    )) {
      final id = 'meal:${++index}';
      final inDay =
          !meal.eatenAt.isBefore(dayStart) && meal.eatenAt.isBefore(day.asOf);
      final before = await beforeBuilder(
        asOf: meal.eatenAt,
        macros: meal.macros,
        mealId: meal.id,
      );
      final outcome = const BuildMealOutcomeContextUseCase()(
        mealTime: meal.eatenAt,
        window: meal.window,
        asOf: history.end,
        builtAt: history.builtAt,
        treatmentHistoryStart: history.start,
        mealId: meal.id,
        glucose: history.glucose ?? [],
        deviceStatuses: history.statuses ?? [],
        treatments: treatments,
        lowTreatments: history.lows ?? [],
        activities: [
          for (final a in history.activities ?? [])
            MealActivityObservation(
              logId: a.logId,
              name: a.name,
              startedAt: a.startedAt,
              endedAt: a.endedAt,
              intensity: null,
            ),
        ],
        subsequentMeals: history.meals == null ? null : recorded,
      );
      results.add((
        reference: id,
        meal: meal,
        analyze: inDay,
        before: before,
        outcome: outcome,
      ));
    }
    return DayAnalysisContext(
      accepted: accepted,
      history: history,
      seriesStart: seriesStart,
      night: night,
      nightIntervals: intervals,
      meals: results,
    );
  }
}
