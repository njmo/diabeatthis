import '../../event/model/foreground_event.dart';
import 'event_matcher.dart';
import 'task_context.dart';

abstract class ForegroundTask {
  const ForegroundTask();

  String get name => runtimeType.toString();

  List<EventMatcher> get eventMatchers;

  bool canHandle(ForegroundEvent event) {
    for (final matcher in eventMatchers) {
      if (matcher.matches(event)) return true;
    }
    return false;
  }

  Future<void> onEvent(ForegroundEvent event, TaskContext context) async {}

  Future<void> onTick(TaskContext context) async {}
}