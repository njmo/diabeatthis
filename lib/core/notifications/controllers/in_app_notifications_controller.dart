import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../base/notifications_controller.dart';
import '../domain/models/notification_event.dart';
import '../in_app/in_app_notification_center.dart';

/// In-app delivery inside the UI isolate: renders the event as a banner.
class InAppNotificationsController implements NotificationsController {
  InAppNotificationsController(this._ref);

  final Ref _ref;

  InAppNotificationCenter get _center =>
      _ref.read(inAppNotificationCenterProvider.notifier);

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) => _center.present(event);

  @override
  Future<void> cancel(int id, {String? tag}) => _center.cancel(id);

  @override
  Future<void> cancelAll() => _center.cancelAll();

  @override
  Future<Iterable<int>> get pending async => const [];

  @override
  Future<void> schedule(NotificationEvent event, Duration when) {
    throw UnsupportedError('In-app notifications cannot be scheduled');
  }
}
