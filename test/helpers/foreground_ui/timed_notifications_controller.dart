import 'package:clock/clock.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';

import '../../foreground/utils/pending_notifications_controller.dart';

/// Records when the fake operating-system notification port receives each event.
class TimedNotificationsController extends PendingNotificationsController {
  TimedNotificationsController({DateTime Function()? now})
    : _now = now ?? clock.now;

  final DateTime Function() _now;
  final shownAt = <({NotificationEvent event, DateTime at})>[];
  final scheduledAt =
      <({NotificationEvent event, Duration delay, DateTime at})>[];

  @override
  Future<void> show(NotificationEvent event) async {
    await super.show(event);
    shownAt.add((event: event, at: _now()));
  }

  @override
  Future<void> schedule(NotificationEvent event, Duration duration) async {
    await super.schedule(event, duration);
    scheduledAt.add((event: event, delay: duration, at: _now()));
  }
}
