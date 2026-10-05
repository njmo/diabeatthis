import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../../core/logger/logger.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../meal_analysis/domain/models/meal_activity_context.dart';
import '../models/accepted_day_summary.dart';
import '../models/day_analysis_history.dart';
import '../models/day_analysis_meal_batch.dart';
import '../models/previous_days_context.dart';

class LoadDayAnalysisHistoryUseCase with Logging {
  final Future<List<Glucose>> Function(DateTime, DateTime) loadGlucose;
  final Future<List<DeviceStatus>> Function(DateTime, DateTime) loadStatuses;
  final Future<List<Treatment>> Function(DateTime, DateTime) loadTreatments;
  final Future<DayAnalysisMealBatch> Function(DateTime, DateTime) loadMeals;
  final Future<List<RecordedLowTreatment>> Function(DateTime, DateTime)
  loadLows;
  final Future<List<MealActivityContext>> Function(DateTime, DateTime)
  loadActivities;
  final Future<PreviousDaysContext> Function(String)? loadPreviousDays;
  final DateTime Function() now;
  const LoadDayAnalysisHistoryUseCase({
    required this.loadGlucose,
    required this.loadStatuses,
    required this.loadTreatments,
    required this.loadMeals,
    required this.loadLows,
    required this.loadActivities,
    required this.now,
    this.loadPreviousDays,
  });

  Future<DayAnalysisHistory> call(AcceptedDaySummary accepted) async {
    final day = accepted.snapshot;
    final builtAt = now();
    final dayStart = DateTime.parse(
      '${day.dayKey}T00:00:00Z',
    ).subtract(Duration(minutes: day.utcOffsetMinutes));
    final first = day.nightStart != null && day.nightStart!.isBefore(dayStart)
        ? day.nightStart!
        : dayStart;
    // Includes the previous meal/eCarbs and a full observation window after midnight.
    final start = first.subtract(const Duration(hours: 24));
    final mealEnd = day.asOf.add(const Duration(hours: 3));
    final requestedEnd = day.nightEnd != null && day.nightEnd!.isAfter(mealEnd)
        ? day.nightEnd!
        : mealEnd;
    final end = requestedEnd.isAfter(builtAt) ? builtAt : requestedEnd;
    final failures = <String>{};
    Future<T?> read<T>(String source, Future<T> Function() action) async {
      try {
        return await action().timeout(const Duration(seconds: 30));
      } catch (error) {
        failures.add(source);
        logW('Day analysis history $source failed: ${error.runtimeType}');
        return null;
      }
    }

    final previousDays = loadPreviousDays == null
        ? Future<PreviousDaysContext?>.value()
        : read('previous_days', () => loadPreviousDays!(day.dayKey));
    final glucose = read('cgm', () => loadGlucose(start, end));
    final statuses = read('device_status', () => loadStatuses(start, end));
    final treatments = read('treatments', () => loadTreatments(start, end));
    final meals = read('meals', () => loadMeals(start, end));
    final lows = read('low_treatments', () => loadLows(start, end));
    final activities = read('activities', () => loadActivities(start, end));
    final mealBatch = await meals;
    if (mealBatch != null && mealBatch.failedIds.isNotEmpty) {
      failures.add('meals');
    }
    return DayAnalysisHistory(
      previousDays: await previousDays,
      start: start,
      end: end,
      builtAt: builtAt,
      glucose: await glucose,
      statuses: await statuses,
      treatments: await treatments,
      meals: mealBatch?.meals,
      failedMealIds: mealBatch?.failedIds ?? {},
      lows: await lows,
      activities: await activities,
      failures: failures,
    );
  }
}
