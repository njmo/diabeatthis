import 'package:diabeatthis/common/monitoring/activity_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/activity_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_phase.dart';
import 'package:diabeatthis/common/monitoring/meal_monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/monitoring_status.dart';
import 'package:diabeatthis/common/monitoring/monitoring_status_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = MonitoringStatusFormatter();
  test(
    'manual continuation retains the meal and describes the next action',
    () {
      final result = formatter.format(
        const MonitoringStatus(
          meal: MealMonitoringStatus(
            phase: MealMonitoringPhase.waitingForUser,
            name: 'Obiad',
          ),
          activity: ActivityMonitoringStatus(
            phase: ActivityMonitoringPhase.idle,
          ),
        ),
      );
      expect(result.title, 'Monitorowanie posiłku');
      expect(result.text, 'Obiad · oczekiwanie na działania w aplikacji');
    },
  );

  test('unavailable activity is visible beside a current meal', () {
    final result = formatter.format(
      const MonitoringStatus(
        meal: MealMonitoringStatus(
          phase: MealMonitoringPhase.eating,
          name: 'Obiad',
        ),
        activity: ActivityMonitoringStatus(
          phase: ActivityMonitoringPhase.unavailable,
        ),
      ),
    );
    expect(result.title, 'Problem z monitorowaniem');
    expect(
      result.text,
      'Obiad · posiłek w trakcie • Aktywność · monitorowanie niedostępne',
    );
  });

  test('does not report idle until both monitors have initialized', () {
    final partial = formatter.format(
      const MonitoringStatus(
        meal: MealMonitoringStatus(phase: MealMonitoringPhase.idle),
      ),
    );
    expect(partial.title, 'Uruchamianie monitorowania');
    expect(partial.text, isNot('Brak bieżących zdarzeń'));
    final idle = formatter.format(
      const MonitoringStatus(
        meal: MealMonitoringStatus(phase: MealMonitoringPhase.idle),
        activity: ActivityMonitoringStatus(phase: ActivityMonitoringPhase.idle),
      ),
    );
    expect(idle.text, 'Brak bieżących zdarzeń');
  });
  test('current activity hides a future meal and uses its start time', () {
    final result = formatter.format(
      MonitoringStatus(
        meal: const MealMonitoringStatus(
          phase: MealMonitoringPhase.planned,
          name: 'Obiad',
        ),
        activity: ActivityMonitoringStatus(
          phase: ActivityMonitoringPhase.active,
          name: 'Spacer',
          startsAt: DateTime(2026, 9, 9, 17, 10),
        ),
      ),
    );
    expect(result.title, 'Monitorowanie aktywności');
    expect(result.text, 'Spacer · od 17:10');
  });
  test('shows both future plans when neither monitor is current', () {
    final result = formatter.format(
      MonitoringStatus(
        meal: MealMonitoringStatus(
          phase: MealMonitoringPhase.planned,
          name: 'Obiad',
          plannedAt: DateTime(2026, 9, 9, 14, 30),
        ),
        activity: ActivityMonitoringStatus(
          phase: ActivityMonitoringPhase.planned,
          name: 'Spacer',
          startsAt: DateTime(2026, 9, 9, 17, 10),
        ),
      ),
    );
    expect(result.title, 'Monitoring aktywny');
    expect(
      result.text,
      'Obiad · zaplanowany na 14:30 • Spacer · zaplanowana na 17:10',
    );
  });
}
