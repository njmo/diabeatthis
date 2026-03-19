import '../domain/models/notification_event.dart';

abstract interface class NotificationsController {
  Future<void> init();
  Future<void> show(NotificationEvent event);
  Future<void> schedule(NotificationEvent event, Duration when);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<Iterable<int>> get pending;
}