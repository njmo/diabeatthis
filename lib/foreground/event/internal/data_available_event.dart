import '../model/foreground_event.dart';

class DataAvailableEvent<T> extends ForegroundEvent {
  final T data;

  DataAvailableEvent(this.data);
}