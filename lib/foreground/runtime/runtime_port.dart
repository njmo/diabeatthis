import '../event/model/foreground_event.dart';

typedef EmitEventFn = void Function(ForegroundEvent event);
typedef EmitSignalFn = void Function(String signalKey);

abstract class RuntimePort {
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;

  const RuntimePort({
    required this.emitEvent,
    required this.emitSignal,
  });

  void log(String message) {
    print('[RuntimePort] $message');
  }
}