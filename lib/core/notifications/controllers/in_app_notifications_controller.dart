import '../../logger/logger.dart';
import '../base/notifications_controller.dart';
import '../domain/models/notification_event.dart';

class InAppNotificationsController with Logging implements NotificationsController {
  InAppNotificationsController();

  @override
  Future<void> init() async {}

  @override
  Future<void> show(NotificationEvent event) async {
    logI("IN APP NOTIFICATION: ${event.title}, ${event.toPayload().toString()}");
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
