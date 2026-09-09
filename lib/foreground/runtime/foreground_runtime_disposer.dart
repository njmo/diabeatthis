import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../collector/foreground_collector.dart';
import 'workflow_scheduler.dart';

class ForegroundRuntimeDisposer with Logging {
  Future<void> dispose({
    required WorkflowScheduler? scheduler,
    required List<ForegroundCollector> collectors,
    required ProviderContainer? container,
  }) async {
    try {
      // Begin all disposals before awaiting: collectors need the scheduler to
      // cancel their waits, while the scheduler may still be waiting for I/O.
      await Future.wait<void>([
        for (final collector in collectors)
          Future<void>.sync(collector.dispose),
        if (scheduler != null) Future<void>.sync(scheduler.dispose),
      ]).timeout(WorkflowScheduler.shutdownTimeout);
    } on TimeoutException {
      logW('Timed out waiting for foreground resources to stop');
    } finally {
      container?.dispose();
    }
  }
}
