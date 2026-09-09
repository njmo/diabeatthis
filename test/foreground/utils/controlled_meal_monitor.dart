import 'package:diabeatthis/foreground/task/base/runtime_context.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/meal_monitor_task.dart';

class ControlledMealMonitor extends MealMonitorTask {
  ControlledMealMonitor(this.runBody);
  final Future<void> Function(RuntimeContext) runBody;

  @override
  Future<void> run(RuntimeContext context) => runBody(context);
}
