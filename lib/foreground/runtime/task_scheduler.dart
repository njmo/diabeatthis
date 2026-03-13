import '../event/model/foreground_event.dart';
import '../task/base/foreground_task.dart';
import '../task/base/task_context.dart';

class TaskScheduler {
  final List<ForegroundTask> _tasks;
  final TaskContext _context;

  TaskScheduler({
    required List<ForegroundTask> tasks,
    required TaskContext context,
  })  : _tasks = List.unmodifiable(tasks),
        _context = context;

  Future<void> handleEvent(ForegroundEvent event) async {
    for (final task in _tasks) {
      if (!task.canHandle(event)) continue;

      try {
        await task.onEvent(event, _context);
      } catch (e, st) {
        _context.log('Task ${task.name} failed in onEvent: $e\n$st');
      }
    }
  }

  Future<void> tick() async {
    for (final task in _tasks) {
      try {
        await task.onTick(_context);
      } catch (e, st) {
        _context.log('Task ${task.name} failed in onTick: $e\n$st');
      }
    }
  }
}