import '../../event/model/foreground_event.dart';

typedef EventPredicate = bool Function(ForegroundEvent event);

class EventMatcher {
  final EventPredicate matches;

  const EventMatcher(this.matches);

  static EventMatcher type<T extends ForegroundEvent>() {
    return EventMatcher((event) => event is T);
  }
}