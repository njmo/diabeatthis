import '../../../common/monitoring/activity_monitoring_status.dart';
import '../../../common/monitoring/meal_monitoring_status.dart';
import '../model/foreground_event.dart';

sealed class MonitoringStatusChanged extends ForegroundEvent {
  const MonitoringStatusChanged();
}

class MealMonitoringStatusChanged extends MonitoringStatusChanged {
  const MealMonitoringStatusChanged(this.status);
  final MealMonitoringStatus status;
}

class ActivityMonitoringStatusChanged extends MonitoringStatusChanged {
  const ActivityMonitoringStatusChanged(this.status);
  final ActivityMonitoringStatus status;
}
