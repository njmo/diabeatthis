import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../common/monitoring/monitoring_notification_content.dart';
import '../../../common/monitoring/monitoring_status.dart';
import '../../../common/monitoring/monitoring_status_formatter.dart';
import '../../event/internal/monitoring_status_changed.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

typedef MonitoringNotificationWriter =
    Future<void> Function(MonitoringNotificationContent content);

class ServiceStatusUpdaterTask extends WorkflowTask {
  const ServiceStatusUpdaterTask({
    this._writer,
    this.retryDelay = const Duration(seconds: 5),
  });
  final MonitoringNotificationWriter? _writer;
  final Duration retryDelay;

  static Future<void> _updateService(
    MonitoringNotificationContent content,
  ) async {
    final result = await FlutterForegroundTask.updateService(
      notificationTitle: content.title,
      notificationText: content.text,
    );
    if (result is ServiceRequestFailure) throw result.error;
  }

  Future<void> _waitBeforeRetry(RuntimeContext context) async {
    final completer = Completer<void>();
    final timer = Timer(retryDelay, completer.complete);
    try {
      await Future.any([completer.future, context.cancellation.onCancel]);
      context.throwIfCancelled();
    } finally {
      timer.cancel();
    }
  }

  @override
  Future<void> run(RuntimeContext context) async {
    final inbox = context.openEventInbox<MonitoringStatusChanged>();
    var current = const MonitoringStatus();
    MonitoringNotificationContent? lastDelivered;
    final writer = _writer ?? _updateService;
    const formatter = MonitoringStatusFormatter();
    try {
      while (true) {
        context.throwIfCancelled();
        final content = formatter.format(current);
        var failed = false;
        if (content != lastDelivered) {
          try {
            await context.cancellation.bind(writer(content));
            lastDelivered = content;
          } on TaskCancelledException {
            rethrow;
          } catch (error) {
            context.log('Monitoring notification update failed: $error');
            failed = true;
            await _waitBeforeRetry(context);
          }
        }
        final events = failed ? inbox.drain() : await inbox.nextBatch();
        for (final event in events) {
          current = switch (event) {
            MealMonitoringStatusChanged(:final status) => MonitoringStatus(
              meal: status,
              activity: current.activity,
            ),
            ActivityMonitoringStatusChanged(:final status) => MonitoringStatus(
              meal: current.meal,
              activity: status,
            ),
          };
        }
      }
    } finally {
      inbox.close();
    }
  }
}
