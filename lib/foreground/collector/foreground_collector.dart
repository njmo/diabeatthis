import '../task/base/collector_context.dart';

abstract class ForegroundCollector {
  void start(CollectorContext context);
  Future<void> dispose();
}