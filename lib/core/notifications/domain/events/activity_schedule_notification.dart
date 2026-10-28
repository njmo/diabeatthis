import 'package:intl/intl.dart';
import '../../../../common/l10n/language.dart';
import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

class ActivityScheduleNotificationEvent implements NotificationEvent {
  const ActivityScheduleNotificationEvent({
    required this.occurrenceId,
    required this.activityName,
    required this.startsAt,
  });
  final int occurrenceId;
  final String activityName;
  final DateTime startsAt;
  @override
  NotificationEventType get type => NotificationEventType.activitySchedule;
  @override
  NotificationKey get key =>
      NotificationKey(type: type, entityId: occurrenceId);
  @override
  String get notificationResponseEvent => 'activity_schedule_response';
  @override
  String get title => lang.activityScheduleConfirmTitle;
  @override
  String get body => lang.activityScheduleConfirmBody(
    activityName,
    DateFormat.Md(lang.localeName).add_Hm().format(startsAt),
  );
  @override
  Map<String, Object?> toPayload() => {
    'response_event_type': notificationResponseEvent,
    'action_data': {'occurrenceId': occurrenceId},
  };
  @override
  Map<String, Object?> toJson() => {
    'occurrenceId': occurrenceId,
    'activityName': activityName,
    'startsAt': startsAt.toIso8601String(),
  };
  factory ActivityScheduleNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) => ActivityScheduleNotificationEvent(
    occurrenceId: json['occurrenceId'] as int,
    activityName: json['activityName'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
  );
}
