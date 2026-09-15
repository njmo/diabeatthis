import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../../common/history/treatment_overlaps_window.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../core/data_sources/providers/on_demand_history_repositories_provider.dart';
import '../../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../../core/domain/model/bg_check.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/domain/model/correction_bolus.dart';
import '../../../../../core/domain/model/extended_carb.dart';
import '../../../../../core/domain/model/manual_bolus.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/stress_event_treatment.dart';
import '../../../../../core/domain/model/temporary_target.dart';
import '../../../../../core/domain/model/treat.dart';
import '../../../../../core/domain/model/treatment_base.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../low_treatment/data/providers/recorded_low_treatment_repository_provider.dart';
import '../../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../../meal_analysis/data/repositories/meal_context_local_history_repository.dart';
import '../../../../meal_analysis/domain/models/meal_activity_observation.dart';
import '../../../../meal_analysis/domain/models/recorded_meal_context.dart';
import '../../../../meal_analysis/domain/use_cases/build_meal_outcome_context_use_case.dart';
import '../../models/meal_analysis_data.dart';
import '../../models/meal_details_data.dart';

part 'analyze_meal_use_case.g.dart';

@Riverpod(keepAlive: true)
AnalyzeMealUseCase analyzeMealUseCase(Ref ref) {
  return AnalyzeMealUseCase(ref: ref);
}

class AnalyzeMealUseCase {
  final Ref ref;

  const AnalyzeMealUseCase({required this.ref});

  Future<MealAnalysisData?> call(
    MealDetailsData details, {
    bool forceCloud = false,
    DateTime? asOf,
  }) async {
    if (!details.meal.isEaten) {
      return null;
    }

    final mealTime = details.analysisTime;
    final chartStart = mealTime.subtract(const Duration(minutes: 45));
    final postMealWindow = details.observationWindow;
    final requestedChartEnd = mealTime.add(postMealWindow);
    final currentTime = clock.now();
    final now = asOf != null && asOf.isBefore(currentTime) ? asOf : currentTime;
    if (now.isBefore(mealTime)) {
      throw ArgumentError.value(asOf, 'asOf', 'Must not precede the meal');
    }
    final chartEnd = requestedChartEnd.isAfter(now) ? now : requestedChartEnd;
    final eventStart = mealTime.subtract(const Duration(hours: 1));
    final eventEnd = chartEnd;
    final targetFetchStart = chartStart.subtract(const Duration(hours: 4));

    final onDemand = forceCloud
        ? await ref.read(onDemandHistoryRepositoriesProvider.future)
        : null;
    final glucoseRepository = onDemand != null
        ? onDemand.glucose
        : await ref.read(glucoseHistoryRepositoryProvider.future);
    final treatmentRepository = onDemand != null
        ? onDemand.treatments
        : await ref.read(treatmentsHistoryRepositoryProvider.future);
    final deviceStatusRepository = onDemand != null
        ? onDemand.deviceStatuses
        : await ref.read(deviceStatusHistoryRepositoryProvider.future);
    // One treatment fetch serves the existing timeline, targets and overlapping
    // earlier eCarbs schedules. Keep the timeline's original event window.
    final treatmentHistoryStart = mealTime.subtract(const Duration(hours: 24));
    final (glucose, treatmentHistory, deviceStatuses) = await (
      glucoseRepository.fetchGlucoseBetween(chartStart, chartEnd),
      treatmentRepository.fetchTreatmentsBetween(
        treatmentHistoryStart,
        chartEnd,
      ),
      deviceStatusRepository.fetchDeviceStatusBetween(chartStart, chartEnd),
    ).wait;
    final treatments = treatmentHistory
        .where((t) => treatmentOverlapsWindow(t, eventStart, eventEnd))
        .toList();
    final targetTreatments = treatmentHistory
        .where(
          (t) =>
              t.createdAt != null && !t.createdAt!.isBefore(targetFetchStart),
        )
        .toList();
    final temporaryTargets = targetTreatments
        .whereType<TemporaryTarget>()
        .where((target) => _overlapsChart(target, chartStart, chartEnd))
        .toList();
    final linkedActivities = await _loadLinkedActivities(eventStart, eventEnd);
    final linkedMeals = await _loadLinkedMeals(
      details.meal.id,
      eventStart,
      eventEnd,
    );
    final lowTreatments = await ref
        .read(recordedLowTreatmentRepositoryProvider)
        .fetchBetween(eventStart, eventEnd);
    final timelineEvents = _buildTimelineEvents(
      lowTreatments: lowTreatments,
      details: details,
      treatments: treatments,
      activities: linkedActivities,
      meals: linkedMeals,
    );

    List<RecordedMealContext>? subsequentMeals;
    try {
      subsequentMeals = await MealContextLocalHistoryRepository(
        ref.read(databaseProvider),
      ).loadMeals(mealTime, chartEnd, details.meal.id);
    } catch (_) {
      // Optional context must not hide the existing charts or timeline.
      subsequentMeals = null;
    }
    final outcome = const BuildMealOutcomeContextUseCase()(
      mealTime: mealTime,
      window: postMealWindow,
      asOf: chartEnd,
      builtAt: clock.now(),
      treatmentHistoryStart: treatmentHistoryStart,
      mealId: details.meal.id,
      glucose: glucose,
      deviceStatuses: deviceStatuses,
      treatments: treatmentHistory,
      lowTreatments: lowTreatments,
      activities: linkedActivities
          .map(
            (a) => MealActivityObservation(
              logId: a.activityLogId,
              name: a.activityName,
              startedAt: a.startedAt,
              endedAt: a.endedAt,
              intensity: a.intensity,
            ),
          )
          .toList(),
      subsequentMeals: subsequentMeals,
    );
    return MealAnalysisData(
      outcomeContext: outcome,
      chartStart: chartStart,
      chartEnd: chartEnd,
      expectedChartEnd: requestedChartEnd,
      eventStart: eventStart,
      eventEnd: eventEnd,
      mealTime: mealTime,
      glucoseReadings: glucose,
      treatments: treatments,
      lowTreatments: lowTreatments,
      temporaryTargets: temporaryTargets,
      deviceStatuses: deviceStatuses,
      linkedActivities: linkedActivities,
      linkedMeals: linkedMeals,
      timelineEvents: timelineEvents,
    );
  }

  Future<List<MealLinkedActivityData>> _loadLinkedActivities(
    DateTime start,
    DateTime end,
  ) async {
    final db = ref.read(databaseProvider);
    final rows = await db.activityDao.getActivityLogsOverlapping(start, end);
    return rows.map((row) {
      final log = row.log;
      final activity = row.activity;
      return MealLinkedActivityData(
        activityLogId: log.id,
        activityName: activity.name,
        startedAt: _date(log.startedAt),
        endedAt: log.endedAt == null ? null : _date(log.endedAt!),
        intensity: log.intensity,
        notes: log.notes,
      );
    }).toList();
  }

  Future<List<MealLinkedMealData>> _loadLinkedMeals(
    int mealId,
    DateTime start,
    DateTime end,
  ) async {
    final db = ref.read(databaseProvider);
    final meals = await db.mealDao.getMealsBetween(
      start,
      end,
      excludeMealId: mealId,
    );
    return meals.map((meal) {
      return MealLinkedMealData(
        mealId: meal.id,
        name: meal.name,
        plannedAt: _date(meal.plannedAt),
        status: meal.status,
      );
    }).toList();
  }

  List<MealTimelineEventData> _buildTimelineEvents({
    required MealDetailsData details,
    required List<Treatment> treatments,
    required List<RecordedLowTreatment> lowTreatments,
    required List<MealLinkedActivityData> activities,
    required List<MealLinkedMealData> meals,
  }) {
    final wizardGrouping = BolusWizardGrouping(treatments);
    final relatedLowTreatmentIds = details.lowTreatments
        .map((treatment) => treatment.meal.id)
        .toSet();
    final events = <MealTimelineEventData>[
      MealTimelineEventData(
        timestamp: details.analysisTime,
        type: MealTimelineEventType.localMeal,
        label: 'Meal eaten',
        value: details.meal.name,
        mealId: details.meal.id,
      ),
      ..._mealStatusEvents(details),
      ...treatments
          .where((treatment) => !wizardGrouping.isRelated(treatment))
          .where(
            (treatment) => treatment.isValid && treatment.createdAt != null,
          )
          .map(_treatmentEvent),
      ...activities.map((activity) {
        return MealTimelineEventData(
          timestamp: activity.startedAt,
          type: MealTimelineEventType.activity,
          label: activity.activityName,
          value: activity.intensity,
          activityLogId: activity.activityLogId,
        );
      }),
      ...meals.map((meal) {
        return MealTimelineEventData(
          timestamp: meal.plannedAt,
          type: MealTimelineEventType.localMeal,
          label: meal.name,
          value: meal.status,
          mealId: meal.mealId,
        );
      }),
      ...details.lowTreatments.map(_lowTreatmentEvent),
      ...lowTreatments
          .where(
            (treatment) => !relatedLowTreatmentIds.contains(treatment.mealId),
          )
          .map(_recordedLowTreatmentEvent),
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  List<MealTimelineEventData> _mealStatusEvents(MealDetailsData details) {
    final historyEvents = details.statusHistory.map((history) {
      return MealTimelineEventData(
        timestamp: history.createdAt,
        type: MealTimelineEventType.mealStatus,
        label: history.status,
      );
    }).toList();

    final currentStatusAlreadyInHistory = historyEvents.any(
      (event) =>
          event.label == details.meal.status &&
          event.timestamp == details.meal.currentStatusTimestamp,
    );
    if (!currentStatusAlreadyInHistory) {
      historyEvents.add(
        MealTimelineEventData(
          timestamp: details.meal.currentStatusTimestamp,
          type: MealTimelineEventType.mealStatus,
          label: details.meal.status,
          value: 'current status',
        ),
      );
    }

    return historyEvents;
  }

  MealTimelineEventData _lowTreatmentEvent(
    MealLowTreatmentDetailsData treatment,
  ) {
    return MealTimelineEventData(
      timestamp: treatment.meal.analysisTime,
      type: MealTimelineEventType.lowTreatment,
      label: treatment.meal.name,
      value: _lowTreatmentValue(treatment),
    );
  }

  String _lowTreatmentValue(MealLowTreatmentDetailsData treatment) {
    final ingredients = treatment.ingredients
        .map(_lowTreatmentIngredientValue)
        .join(', ');
    final total = '${_formatNumber(treatment.totalNetCarbsG)} g netto';

    if (ingredients.isEmpty) {
      return total;
    }
    return '$ingredients • $total';
  }

  String _lowTreatmentIngredientValue(MealIngredientDetailsData ingredient) {
    return '${ingredient.ingredientName} ${_formatNumber(ingredient.consumedTotalGrams)} g';
  }

  MealTimelineEventData _recordedLowTreatmentEvent(
    RecordedLowTreatment treatment,
  ) {
    final carbs = treatment.netCarbsGrams;
    return MealTimelineEventData(
      timestamp: treatment.eatenAt,
      type: MealTimelineEventType.lowTreatment,
      label: lang.lowTreatmentMealName,
      value: carbs == null
          ? lang.uiUnknownAmount
          : lang.mealNetCarbsAmount(_formatNumber(carbs)),
    );
  }

  MealTimelineEventData _treatmentEvent(Treatment treatment) {
    final createdAt = treatment.createdAt ?? clock.now();
    if (treatment is BgCheck) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.bgCheck,
        label: lang.historyBgCheck,
        value: treatment.getParts(),
      );
    }
    if (treatment is StressEventTreatment) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.stress,
        label: lang.manualEventStress,
        value: treatment.getParts(),
      );
    }
    if (treatment is BolusWizard) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.bolusWizard,
        label: lang.uiBolusWizard,
        value: treatment.getParts(),
      );
    }
    if (treatment is ManualBolus) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.manualCorrection,
        label: lang.mealReviewManualCorrection,
        value: treatment.getParts(),
      );
    }
    if (treatment is CorrectionBolus) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.correction,
        label: lang.activityTreatmentCorrection,
        value: treatment.getParts(),
      );
    }
    if (treatment is Meal) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.nightscoutMeal,
        label: lang.activityTreatmentMeal,
        value: treatment.getParts(),
      );
    }
    if (treatment is Treat || treatment is ExtendedCarb) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.carbs,
        label: lang.mealCarbsLabel,
        value: treatment.getParts(),
      );
    }
    if (treatment is TemporaryTarget) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.tempTarget,
        label: lang.historyTemporaryTarget,
        value: treatment.getParts(),
      );
    }
    return MealTimelineEventData(
      timestamp: createdAt,
      type: MealTimelineEventType.deviceStatus,
      label: lang.mealTimelineTreatment,
      value: treatment.getParts(),
    );
  }

  DateTime _date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }

  bool _overlapsChart(
    TemporaryTarget target,
    DateTime chartStart,
    DateTime chartEnd,
  ) {
    final targetEnd = target.createdAt.add(Duration(minutes: target.duration));
    return target.createdAt.isBefore(chartEnd) && targetEnd.isAfter(chartStart);
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }
}
