import '../l10n/language.dart';
import 'activity_monitoring_phase.dart';
import 'meal_monitoring_phase.dart';
import 'monitoring_notification_content.dart';
import 'monitoring_status.dart';

class MonitoringStatusFormatter {
  const MonitoringStatusFormatter();

  MonitoringNotificationContent format(MonitoringStatus status) {
    final meal = status.meal;
    final activity = status.activity;
    final hasUnavailable = meal.isUnavailable || activity.isUnavailable;
    final hasCurrent = meal.isCurrent || activity.isCurrent || hasUnavailable;
    final lines = <String>[];
    final mealDetail = switch (meal.phase) {
      MealMonitoringPhase.initializing || MealMonitoringPhase.idle => null,
      MealMonitoringPhase.unavailable => lang.uiMonitoringUnavailable,
      MealMonitoringPhase.waitingForUser => lang.uiWaitingForActionsInTheApp,
      MealMonitoringPhase.planned => lang.monitoringMealPlanned(
        _at(meal.plannedAt),
      ),
      MealMonitoringPhase.preparing => lang.uiPreparingForAMeal,
      MealMonitoringPhase.waitingForBolus => lang.uiWaitingForABolus,
      MealMonitoringPhase.waitingToEat => lang.uiWaitingToStartEating,
      MealMonitoringPhase.eating => lang.uiMealInProgress,
      MealMonitoringPhase.eatingThenBolus =>
        lang.uiMealInProgressBolusAfterEating,
      MealMonitoringPhase.eatingExtra => lang.uiExtraFoodInProgress,
    };
    final activityDetail = switch (activity.phase) {
      ActivityMonitoringPhase.initializing ||
      ActivityMonitoringPhase.idle => null,
      ActivityMonitoringPhase.unavailable => lang.uiMonitoringUnavailable,
      ActivityMonitoringPhase.planned => lang.monitoringActivityPlanned(
        _at(activity.startsAt),
      ),
      ActivityMonitoringPhase.preparing => lang.uiPreparingForActivity,
      ActivityMonitoringPhase.active =>
        activity.startsAt == null
            ? lang.uiActivityInProgress
            : lang.monitoringActivitySince(_time(activity.startsAt!)),
      ActivityMonitoringPhase.waitingForFinish =>
        lang.uiWaitingForFinishConfirmation,
    };
    if (mealDetail != null &&
        (!hasCurrent || meal.isCurrent || meal.isUnavailable)) {
      lines.add(
        '${_name(meal.name, lang.activityTreatmentMeal)} · $mealDetail',
      );
    }
    if (activityDetail != null &&
        (!hasCurrent || activity.isCurrent || activity.isUnavailable)) {
      lines.add(
        '${_name(activity.name, lang.activityTitle)} · $activityDetail',
      );
    }
    final initializing =
        meal.phase == MealMonitoringPhase.initializing ||
        activity.phase == ActivityMonitoringPhase.initializing;
    final title = hasUnavailable
        ? lang.uiMonitoringProblem
        : meal.isCurrent && activity.isCurrent
        ? lang.uiMealAndActivityMonitoring
        : meal.isCurrent
        ? lang.uiMealMonitoring
        : activity.isCurrent
        ? lang.uiActivityMonitoring
        : initializing
        ? lang.uiStartingMonitoring
        : lang.uiMonitoringActive;
    return MonitoringNotificationContent(
      title,
      lines.isNotEmpty
          ? lines.join(' • ')
          : initializing
          ? lang.uiLoadingMealsAndActivities
          : lang.uiNoCurrentEvents,
    );
  }

  String _name(String? value, String fallback) =>
      value == null || value.trim().isEmpty
      ? fallback
      : value.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _at(DateTime? date) =>
      date == null ? '' : lang.monitoringScheduledAt(_time(date));
  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
