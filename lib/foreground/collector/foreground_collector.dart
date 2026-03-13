import '../runtime/event_dispatcher.dart';

abstract class ForegroundCollector {
  const ForegroundCollector();

  Future<void> collect(EventDispatcher dispatcher);
}