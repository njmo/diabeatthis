import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class TempTargetDeliveryNotification implements NotificationEvent {
  const TempTargetDeliveryNotification({required this.message});

  final String message;

  @override
  NotificationEventType get type => NotificationEventType.tempTargetDelivery;
  @override
  NotificationKey get key => NotificationKey(type: type, entityId: 0);
  @override
  String get title => lang.notificationTempTargetTitle;
  @override
  String get body => message;
  @override
  String get notificationResponseEvent => '';
  @override
  Map<String, Object?> toJson() => {'message': message};
  @override
  Map<String, Object?> toPayload() => {};
}
