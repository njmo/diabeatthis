import '../../core/logger/logger.dart';
import '../runtime/task_cancelled_exception.dart';
import '../task/base/collector_context.dart';

abstract class ForegroundCollector with Logging {
  Future<void> runGuarded(Future<void> Function() run) async {
    try {
      await run();
    } on TaskCancelledException {
      // Scheduler disposal cancels pending collector waits.
    }
  }

  void start(CollectorContext context);
  Future<void> dispose();
}
