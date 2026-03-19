import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_in_app_notification_payload.dart';
import '../../../foreground/providers/task_event_router_provider.dart';
import '../base/notifications_controller.dart';
import '../domain/models/notification_event.dart';

class ForegroundTaskNotificationController implements NotificationsController{
  final Ref _ref;
  ForegroundTaskNotificationController(this._ref);

  Future<void> init() async {}

  Future<void> show(NotificationEvent event) async {
    final payload = TaskInAppNotificationPayload(type: event.type, data: event.toJson());
    _ref.read(taskEventRouterProvider).send(payload);
  }

  @override
  Future<void> cancel(int id) {
    // TODO: implement cancel
    throw UnimplementedError();
  }

  @override
  Future<void> cancelAll() {
    // TODO: implement cancelAll
    throw UnimplementedError();
  }

  @override
  // TODO: implement pending
  Future<Iterable<int>> get pending => throw UnimplementedError();

  @override
  Future<void> schedule(NotificationEvent event, Duration when) {
    // TODO: implement schedule
    throw UnimplementedError();
  }
}
