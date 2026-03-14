import '../../../common/events/data/notification/eat_now_response_event.dart';
import '../../event/internal/meal_status_changed_event.dart';
import '../../event/model/foreground_event.dart';
import '../base/event_matcher.dart';
import '../base/foreground_task.dart';
import '../base/task_context.dart';

class MealMonitorTask extends ForegroundTask {
  int? _activeMealId;

  @override
  List<EventMatcher> get eventMatchers => [
    EventMatcher.type<MealStatusChangedEvent>(),
  ];

  @override
  Future<void> onEvent(ForegroundEvent event, TaskContext context) async {
    if (event is MealStatusChangedEvent) {
      event.when(
        eating: (mealId) {
          print('MealMonitorTask: started eating meal $mealId');
          _activeMealId = mealId;
        },
        eaten: (mealId) {
          print('MealMonitorTask: finished eating meal $mealId');
          _activeMealId = null;
        },
        skipped: (mealId) {
          print('MealMonitorTask: skipped meal $mealId');
          _activeMealId = null;
        },
        eatingThenBolus: (mealId) {
          print('MealMonitorTask: eating then bolus meal $mealId');
          _activeMealId = mealId;
        },
        bolusedWaiting: (mealId) {
          print('MealMonitorTask: bolused waiting meal $mealId');
          _activeMealId = mealId;
        },
        bolusedEating: (mealId) {
          print('MealMonitorTask: bolused eating meal $mealId');
          _activeMealId = mealId;
        },
      );
    }
  }

  @override
  Future<void> onTick(TaskContext context) async {
    if (_activeMealId == null) return;

    print("Monitoring meal");
  }
}
