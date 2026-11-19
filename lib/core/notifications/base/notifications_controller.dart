import '../domain/models/notification_event.dart';

abstract interface class NotificationsController {
  Future<void> init();
  Future<void> show(NotificationEvent event);
  Future<void> schedule(NotificationEvent event, Duration when);

  /// Withdraws a notification; [tag] completes its Android identity when it
  /// was posted with one.
  Future<void> cancel(int id, {String? tag});
  Future<void> cancelAll();
  Future<Iterable<int>> get pending;
}
