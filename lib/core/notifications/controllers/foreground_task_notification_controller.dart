import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/events/data/task/task_in_app_notification_payload.dart';
import '../../../common/events/data/task/task_notification_inbox_changed_payload.dart';
import '../../../foreground/providers/task_event_router_provider.dart';
import '../base/notifications_controller.dart';
import '../domain/models/notification_event.dart';

/// In-app delivery from the foreground-service isolate: forwards the event to
/// the UI isolate, which renders it as a banner.
class ForegroundTaskNotificationController implements NotificationsController {
  final Ref _ref;
  ForegroundTaskNotificationController(this._ref);

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) async {
    final payload = TaskInAppNotificationPayload(
      type: event.type,
      data: event.toJson(),
    );
    _ref.read(taskEventRouterProvider).send(payload);
  }

  /// Lets the UI refresh its inbox after the service posted a system
  /// notification.
  void notifyInboxChanged() {
    _ref
        .read(taskEventRouterProvider)
        .send(const TaskNotificationInboxChangedPayload());
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    _ref
        .read(taskEventRouterProvider)
        .send(TaskNotificationInboxChangedPayload(dismissedIds: [id]));
  }

  @override
  Future<void> cancelAll() async {
    _ref
        .read(taskEventRouterProvider)
        .send(const TaskNotificationInboxChangedPayload(dismissAll: true));
  }

  @override
  Future<Iterable<int>> get pending async => const [];

  @override
  Future<void> schedule(NotificationEvent event, Duration when) {
    throw UnsupportedError('In-app notifications cannot be scheduled');
  }
}
