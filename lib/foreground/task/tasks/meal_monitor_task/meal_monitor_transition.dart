import 'executors/meal_monitor_state_executor.dart';
import 'meal_monitor_context.dart';

class MealMonitorTransition {
  final MealMonitorContext? context;
  final MealMonitorStateExecutor executor;

  MealMonitorTransition(this.context, this.executor);
}