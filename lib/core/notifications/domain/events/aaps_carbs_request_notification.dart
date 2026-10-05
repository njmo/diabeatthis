import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class AapsCarbsRequestNotificationEvent implements NotificationEvent {
  final String episodeId;
  final double carbs;
  const AapsCarbsRequestNotificationEvent({
    required this.episodeId,
    required this.carbs,
  });

  @override
  NotificationEventType get type => NotificationEventType.aapsCarbsRequest;

  @override
  String get notificationResponseEvent => 'aaps_carbs_request_response';

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: 0);

  @override
  String get title => lang.notificationAapsCarbsRequestTitle(_grams(carbs));

  @override
  String get body => lang.notificationAapsCarbsRequestBody;

  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'episodeId': episodeId},
  };

  @override
  Map<String, Object?> toJson() => {'episodeId': episodeId, 'carbs': carbs};

  factory AapsCarbsRequestNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) => AapsCarbsRequestNotificationEvent(
    episodeId: json['episodeId'] as String,
    carbs: (json['carbs'] as num).toDouble(),
  );

  static String _grams(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
