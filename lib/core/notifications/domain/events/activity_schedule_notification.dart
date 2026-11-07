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
    this.revision = 0,
  });
  final int occurrenceId;
  final int revision;
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
    'action_data': {
      'occurrenceId': occurrenceId,
      'expectedStartedAt': startsAt.millisecondsSinceEpoch,
      'expectedRevision': revision,
    },
  };
  @override
  Map<String, Object?> toJson() => {
    'occurrenceId': occurrenceId,
    'activityName': activityName,
    'startsAt': startsAt.toIso8601String(),
    'revision': revision,
  };
  factory ActivityScheduleNotificationEvent.fromPayload(
    Map<String, dynamic> json,
  ) => ActivityScheduleNotificationEvent(
    occurrenceId: json['occurrenceId'] as int,
    activityName: json['activityName'] as String,
    startsAt: DateTime.parse(json['startsAt'] as String),
    revision: json['revision'] as int? ?? 0,
  );
}
