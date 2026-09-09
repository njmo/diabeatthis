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
      MealMonitoringPhase.unavailable => 'monitorowanie niedostępne',
      MealMonitoringPhase.waitingForUser =>
        'oczekiwanie na działania w aplikacji',
      MealMonitoringPhase.planned => 'zaplanowany${_at(meal.plannedAt)}',
      MealMonitoringPhase.preparing => 'przygotowanie do posiłku',
      MealMonitoringPhase.waitingForBolus => 'oczekiwanie na bolus',
      MealMonitoringPhase.waitingToEat => 'oczekiwanie na rozpoczęcie jedzenia',
      MealMonitoringPhase.eating => 'posiłek w trakcie',
      MealMonitoringPhase.eatingThenBolus =>
        'posiłek w trakcie, bolus po jedzeniu',
      MealMonitoringPhase.eatingExtra => 'dokładka w trakcie',
    };
    final activityDetail = switch (activity.phase) {
      ActivityMonitoringPhase.initializing ||
      ActivityMonitoringPhase.idle => null,
      ActivityMonitoringPhase.unavailable => 'monitorowanie niedostępne',
      ActivityMonitoringPhase.planned => 'zaplanowana${_at(activity.startsAt)}',
      ActivityMonitoringPhase.preparing => 'przygotowanie do aktywności',
      ActivityMonitoringPhase.active =>
        activity.startsAt == null
            ? 'aktywność w trakcie'
            : 'od ${_time(activity.startsAt!)}',
      ActivityMonitoringPhase.waitingForFinish =>
        'oczekiwanie na potwierdzenie zakończenia',
    };
    if (mealDetail != null &&
        (!hasCurrent || meal.isCurrent || meal.isUnavailable)) {
      lines.add('${_name(meal.name, 'Posiłek')} · $mealDetail');
    }
    if (activityDetail != null &&
        (!hasCurrent || activity.isCurrent || activity.isUnavailable)) {
      lines.add('${_name(activity.name, 'Aktywność')} · $activityDetail');
    }
    final initializing =
        meal.phase == MealMonitoringPhase.initializing ||
        activity.phase == ActivityMonitoringPhase.initializing;
    final title = hasUnavailable
        ? 'Problem z monitorowaniem'
        : meal.isCurrent && activity.isCurrent
        ? 'Monitorowanie posiłku i aktywności'
        : meal.isCurrent
        ? 'Monitorowanie posiłku'
        : activity.isCurrent
        ? 'Monitorowanie aktywności'
        : initializing
        ? 'Uruchamianie monitorowania'
        : 'Monitoring aktywny';
    return MonitoringNotificationContent(
      title,
      lines.isNotEmpty
          ? lines.join(' • ')
          : initializing
          ? 'Odczytywanie posiłków i aktywności…'
          : 'Brak bieżących zdarzeń',
    );
  }

  String _name(String? value, String fallback) =>
      value == null || value.trim().isEmpty
      ? fallback
      : value.replaceAll(RegExp(r'\s+'), ' ').trim();
  String _at(DateTime? date) => date == null ? '' : ' na ${_time(date)}';
  String _time(DateTime date) {
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
