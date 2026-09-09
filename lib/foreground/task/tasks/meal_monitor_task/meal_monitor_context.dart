import '../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../common/monitoring/meal_monitoring_status.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../event/internal/monitoring_status_changed.dart';
import '../../base/runtime_context.dart';

class MealMonitorContext {
  MealMonitoringStatus? _lastPublishedStatus;
  void publishStatus(RuntimeContext context, MealMonitoringPhase phase) {
    context.throwIfCancelled();
    final status = phase == MealMonitoringPhase.idle
        ? const MealMonitoringStatus(phase: MealMonitoringPhase.idle)
        : MealMonitoringStatus(
            phase: phase,
            mealId: activeMeal?.id,
            name: activeMeal?.name,
            plannedAt: activeMeal?.plannedAt,
          );
    if (status == _lastPublishedStatus) return;
    _lastPublishedStatus = status;
    context.emitEvent(MealMonitoringStatusChanged(status));
  }

  Meal? activeMeal;

  MealMonitorContext({this.activeMeal});

  MealMonitorContext copyWith({bool? shouldBolus, Meal? activeMeal}) {
    return MealMonitorContext(activeMeal: activeMeal ?? this.activeMeal);
  }
}
