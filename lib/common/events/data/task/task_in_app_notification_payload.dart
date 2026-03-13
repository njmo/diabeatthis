import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/notifications/domain/models/notification_event_type.dart';
import '../../task_event_payload.dart';

part 'task_in_app_notification_payload.freezed.dart';
part 'task_in_app_notification_payload.g.dart';

@freezed
abstract class TaskInAppNotificationPayload
    with _$TaskInAppNotificationPayload, TaskEventPayload {
  const TaskInAppNotificationPayload._();

  const factory TaskInAppNotificationPayload({
    required NotificationEventType type,
    required Map<String, dynamic> data
  }) = _TaskInAppNotificationPayload;

  factory TaskInAppNotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$TaskInAppNotificationPayloadFromJson(json);

  @override
  String get eventName => 'task_in_app_notification';
}