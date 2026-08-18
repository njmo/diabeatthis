import '../../../../common/events/data/notification/temp_target_type.dart';
import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class TempTargetNotificationEvent implements NotificationEvent {
  TempTargetNotificationEvent({
    required this.entityId,
    required this.targetType,
    String? tempTargetString,
  }) : tempTargetString =
           tempTargetString ?? TempTargetType.displayName(targetType);

  factory TempTargetNotificationEvent.meal({required int entityId}) {
    return TempTargetNotificationEvent(
      entityId: entityId,
      targetType: TempTargetType.meal,
    );
  }

  factory TempTargetNotificationEvent.activity({required int entityId}) {
    return TempTargetNotificationEvent(
      entityId: entityId,
      targetType: TempTargetType.activity,
    );
  }

  final int entityId;
  final String targetType;
  final String tempTargetString;

  @override
  NotificationEventType get type => NotificationEventType.tempTarget;

  @override
  String get notificationResponseEvent => 'temp_target_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: 0);

  @override
  String get title => lang.notificationTempTargetTitle;

  @override
  String get body => lang.notificationTempTargetBody(tempTargetString);

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {
      'entityId': entityId,
      'targetType': targetType,
      'tempTargetString': tempTargetString,
    },
  };

  @override
  Map<String, Object?> toJson() => {
    'entityId': entityId.toString(),
    'targetType': targetType,
    'tempTargetString': tempTargetString,
  };

  factory TempTargetNotificationEvent.fromPayload(Map<String, dynamic> json) {
    return TempTargetNotificationEvent(
      entityId: _parseId(json['entityId']),
      targetType: json['targetType'] as String,
      tempTargetString: json['tempTargetString'] as String,
    );
  }

  static int _parseId(Object? value) {
    if (value is int) {
      return value;
    }
    return int.parse(value as String);
  }
}
