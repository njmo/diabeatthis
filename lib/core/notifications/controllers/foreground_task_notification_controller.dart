import '../application/notifications_controller.dart';
import '../domain/models/notification_event.dart';

class ForegroundTaskNotificationController implements NotificationsController{
  ForegroundTaskNotificationController();

  Future<void> init() async {}

  Future<void> show(NotificationEvent event) async {}

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
