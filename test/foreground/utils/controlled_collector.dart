import 'package:diabeatthis/foreground/collector/foreground_collector.dart';
import 'package:diabeatthis/foreground/task/base/collector_context.dart';

class ControlledCollector extends ForegroundCollector {
  ControlledCollector(this.onDispose);
  final Future<void> Function() onDispose;
  bool stopped = false;

  @override
  void start(CollectorContext context) {}

  @override
  Future<void> dispose() {
    stopped = true;
    return onDispose();
  }
}
