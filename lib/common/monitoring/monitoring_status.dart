import 'activity_monitoring_phase.dart';
import 'activity_monitoring_status.dart';
import 'meal_monitoring_phase.dart';
import 'meal_monitoring_status.dart';

class MonitoringStatus {
  const MonitoringStatus({
    this.meal = const MealMonitoringStatus(
      phase: MealMonitoringPhase.initializing,
    ),
    this.activity = const ActivityMonitoringStatus(
      phase: ActivityMonitoringPhase.initializing,
    ),
  });
  final MealMonitoringStatus meal;
  final ActivityMonitoringStatus activity;
}
