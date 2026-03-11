import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../common/events/payloads/task/task_in_app_notification_payload.dart';
import '../../../common/events/task_event_payload.dart';

part 'task_event.freezed.dart';
part 'task_event.g.dart';

@Freezed(
  unionKey: 'event',
  unionValueCase: FreezedUnionCase.snake,
)
sealed class TaskEvent with _$TaskEvent {
  const TaskEvent._();

  const factory TaskEvent.taskInAppNotification({
    required TaskInAppNotificationPayload data,
  }) = TaskInAppNotificationEvent;

  factory TaskEvent.fromJson(Map<String, dynamic> json) =>
      _$TaskEventFromJson(json);

  factory TaskEvent.fromPayload(TaskEventPayload payload) {
    return switch (payload) {
      final TaskInAppNotificationPayload p => TaskEvent.taskInAppNotification(data: p),
      _ => throw UnsupportedError(
        'Unsupported payloads type: ${payload.runtimeType}',
      ),
    };
  }
}