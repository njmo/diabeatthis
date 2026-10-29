import '../../../../common/events/data/notification/temp_target_type.dart';
import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class TempTargetNotificationEvent implements NotificationEvent {
  TempTargetNotificationEvent({
    required this.entityId,
    required this.targetType,
    this.requestId,
    this.target,
    this.durationMinutes,
    this.renewal = false,
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

  final String? requestId;
  final int? target;
  final int? durationMinutes;
  final bool renewal;
  final int entityId;
  final String targetType;
  final String tempTargetString;

  @override
  NotificationEventType get type => NotificationEventType.tempTarget;

  @override
  String get notificationResponseEvent => 'temp_target_response';

  @override
  NotificationKey get key => NotificationKey(
    type: type,
    entityId: entityId * 2 + (targetType == TempTargetType.activity ? 1 : 0),
  );

  @override
  String get title => requestId == null
      ? lang.notificationTempTargetManualTitle
      : lang.notificationTempTargetTitle;

  @override
  String get body => requestId == null
      ? switch (targetType) {
          TempTargetType.activity => lang.notificationTempTargetManualActivity,
          TempTargetType.meal => lang.notificationTempTargetManualMeal,
          _ => lang.notificationTempTargetBody(tempTargetString),
        }
      : renewal
      ? lang.notificationTempTargetRenewal(target!, durationMinutes!)
      : lang.notificationTempTargetConsent(target!, durationMinutes!);

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {
      'entityId': entityId,
      if (requestId != null) 'requestId': requestId,
      'targetType': targetType,
      'tempTargetString': tempTargetString,
    },
  };

  @override
  Map<String, Object?> toJson() => {
    'entityId': entityId.toString(),
    'requestId': requestId,
    'target': target,
    'durationMinutes': durationMinutes,
    'renewal': renewal,
    'targetType': targetType,
    'tempTargetString': tempTargetString,
  };

  factory TempTargetNotificationEvent.fromPayload(Map<String, dynamic> json) {
    return TempTargetNotificationEvent(
      entityId: _parseId(json['entityId']),
      requestId: json['requestId'] as String?,
      target: json['target'] as int?,
      durationMinutes: json['durationMinutes'] as int?,
      renewal: json['renewal'] as bool? ?? false,
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
