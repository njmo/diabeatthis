import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../../core/domain/model/correction_bolus.dart';
import '../../../../../core/domain/model/extended_carb.dart';
import '../../../../../core/domain/model/manual_bolus.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/domain/model/treat.dart';
import '../../../../../core/domain/model/treatment_base.dart';
import '../../../../../core/drift/providers/database_provider.dart';
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

  Future<MealAnalysisData?> call(MealDetailsData details) async {
    if (!details.meal.isEaten) {
      return null;
    }

    final mealTime = details.meal.analysisTime;
    final chartStart = mealTime.subtract(const Duration(minutes: 45));
    final requestedChartEnd = mealTime.add(const Duration(minutes: 90));
    final now = clock.now();
    final chartEnd = requestedChartEnd.isAfter(now) ? now : requestedChartEnd;
    final eventStart = mealTime.subtract(const Duration(hours: 1));
    final eventEnd = chartEnd;

    final repository = await ref.read(nightscoutRepositoryProvider.future);
    final glucose = await repository.fetchGlucoseBetween(chartStart, chartEnd);
    final treatments = await repository.fetchTreatmentsBetween(
      eventStart,
      eventEnd,
    );
    final deviceStatuses = await repository.fetchDeviceStatusBetween(
      chartStart,
      chartEnd,
    );
    final linkedActivities = await _loadLinkedActivities(eventStart, eventEnd);
    final linkedMeals = await _loadLinkedMeals(
      details.meal.id,
      eventStart,
      eventEnd,
    );
    final timelineEvents = _buildTimelineEvents(
      details: details,
      treatments: treatments,
      activities: linkedActivities,
      meals: linkedMeals,
    );

    return MealAnalysisData(
      chartStart: chartStart,
      chartEnd: chartEnd,
      eventStart: eventStart,
      eventEnd: eventEnd,
      mealTime: mealTime,
      glucoseReadings: glucose,
      treatments: treatments,
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
      final log = row.readTable(db.activityLog);
      final activity = row.readTable(db.activity);
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
    required List<MealLinkedActivityData> activities,
    required List<MealLinkedMealData> meals,
  }) {
    final events = <MealTimelineEventData>[
      MealTimelineEventData(
        timestamp: details.meal.analysisTime,
        type: MealTimelineEventType.meal,
        label: 'Meal eaten',
        value: details.meal.name,
        mealId: details.meal.id,
      ),
      ..._mealStatusEvents(details),
      ...treatments.map(_treatmentEvent),
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
          type: MealTimelineEventType.meal,
          label: meal.name,
          value: meal.status,
          mealId: meal.mealId,
        );
      }),
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

    final currentStatusAlreadyInHistory = details.statusHistory.any(
      (history) => history.status == details.meal.status,
    );
    if (!currentStatusAlreadyInHistory) {
      historyEvents.add(
        MealTimelineEventData(
          timestamp: _currentMealStatusTimestamp(details.meal),
          type: MealTimelineEventType.mealStatus,
          label: details.meal.status,
          value: 'current status',
        ),
      );
    }

    return historyEvents;
  }

  DateTime _currentMealStatusTimestamp(MealRecordData meal) {
    if (meal.summarizedAt != null &&
        (meal.status == 'summarized' || meal.status.startsWith('eaten'))) {
      return meal.summarizedAt!;
    }
    return meal.updatedAt;
  }

  MealTimelineEventData _treatmentEvent(Treatment treatment) {
    final createdAt = treatment.createdAt ?? clock.now();
    if (treatment is ManualBolus) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.insulin,
        label: 'Bolus',
        value: treatment.getParts(),
      );
    }
    if (treatment is CorrectionBolus) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.correction,
        label: 'Correction',
        value: treatment.getParts(),
      );
    }
    if (treatment is Treat || treatment is ExtendedCarb || treatment is Meal) {
      return MealTimelineEventData(
        timestamp: createdAt,
        type: MealTimelineEventType.carbs,
        label: 'Carbs',
        value: treatment.getParts(),
      );
    }
    return MealTimelineEventData(
      timestamp: createdAt,
      type: MealTimelineEventType.deviceStatus,
      label: 'Treatment',
      value: treatment.getParts(),
    );
  }

  DateTime _date(int millisecondsSinceEpoch) {
    return DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
  }
}
