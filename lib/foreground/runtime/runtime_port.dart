import '../../core/logger/logger.dart';
import '../event/model/foreground_event.dart';
import 'wait_handle.dart';

typedef EmitEventFn = void Function(ForegroundEvent event);
typedef EmitSignalFn = void Function(String signalKey);
typedef DurationWaitFn = WaitHandle<void> Function(Duration duration);
typedef SignalWaitFn = WaitHandle<void> Function(String signalKey);
typedef WaitForDurationFn = Future<void> Function(Duration duration);
typedef WaitForSignalFn = Future<void> Function(String signalKey);


abstract class RuntimePort with Logging {
  final EmitEventFn emitEvent;
  final EmitSignalFn emitSignal;
  final WaitForDurationFn waitForDuration;
  final DurationWaitFn durationWait;
  final WaitForSignalFn waitForSignal;
  final SignalWaitFn signalWait;

  const RuntimePort({
    required this.emitEvent,
    required this.emitSignal,
    required this.waitForDuration,
    required this.waitForSignal,
    required this.durationWait,
    required this.signalWait,
  });

  void log(String message) {
    logI(message);
  }
}
