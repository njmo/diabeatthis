import '../../core/logger/logger.dart';
import '../task/base/collector_context.dart';

abstract class ForegroundCollector with Logging {
  void start(CollectorContext context);
  Future<void> dispose();
}