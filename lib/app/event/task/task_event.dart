import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../common/events/data/task/task_data_synchronization_payload.dart';
import '../../../common/events/data/task/task_in_app_notification_payload.dart';
import '../../../common/events/data/task/task_state_synchronization_payload.dart';
import '../../../common/events/task_event_payload.dart';

part 'task_event.freezed.dart';
part 'task_event.g.dart';

@Freezed(unionKey: 'event', unionValueCase: FreezedUnionCase.snake)
sealed class TaskEvent with _$TaskEvent {
  const TaskEvent._();

  const factory TaskEvent.taskInAppNotification({
    required TaskInAppNotificationPayload data,
  }) = TaskInAppNotificationEvent;

  const factory TaskEvent.taskDataSynchronization({
    required TaskDataSynchronizationPayload data,
  }) = TaskDataSynchronizationEvent;

  const factory TaskEvent.taskStateSynchronization({
    required TaskStateSynchronizationPayload data,
  }) = TaskStateSynchronizationEvent;

  factory TaskEvent.fromJson(Map<String, dynamic> json) =>
      _$TaskEventFromJson(json);
}
