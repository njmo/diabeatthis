import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/runtime_port.dart';
import 'runtime_context.dart';

class CollectorContext extends RuntimePort {
  final ProviderContainer container;

  CollectorContext({
    required this.container,
    required super.emitEvent,
    required super.emitSignal,
    required super.waitForDuration,
    required super.waitForSignal,
    required super.durationWait,
    required super.signalWait,
  });

  static fromRuntimeContext(RuntimeContext runtimeContext) {
    return CollectorContext(
      container: runtimeContext.container,
      emitEvent: runtimeContext.emitEvent,
      emitSignal: runtimeContext.emitSignal,
      waitForDuration: runtimeContext.waitForDuration,
      waitForSignal: runtimeContext.waitForSignal,
      durationWait: runtimeContext.durationWait,
      signalWait: runtimeContext.signalWait,
    );
  }
}
