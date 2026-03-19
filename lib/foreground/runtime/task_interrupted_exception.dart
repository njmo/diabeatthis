import '../event/model/foreground_event.dart';

class TaskInterruptedException implements Exception {
  final ForegroundEvent event;

  const TaskInterruptedException(this.event);

  @override
  String toString() => 'TaskInterruptedException(event: $event)';
}