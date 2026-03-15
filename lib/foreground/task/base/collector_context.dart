import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/runtime_port.dart';
import 'runtime_context.dart';

class CollectorContext extends RuntimePort {
  final ProviderContainer container;

  CollectorContext({
    required this.container,
    required super.emitEvent,
    required super.emitSignal,
  });

  static fromRuntimeContext(RuntimeContext runtimeContext) {
    return CollectorContext(
      container: runtimeContext.container,
      emitEvent: runtimeContext.emitEvent,
      emitSignal: runtimeContext.emitSignal,
    );
  }
}
