import 'package:freezed_annotation/freezed_annotation.dart';

import '../../task_event_payload.dart';

part 'task_state_synchronization_payload.freezed.dart';
part 'task_state_synchronization_payload.g.dart';

@freezed
abstract class TaskStateSynchronizationPayload
    with _$TaskStateSynchronizationPayload, TaskEventPayload {
  const TaskStateSynchronizationPayload._();

  const factory TaskStateSynchronizationPayload.alive({required bool data}) =
      TaskAliveStateSynchronization;

  factory TaskStateSynchronizationPayload.fromJson(Map<String, dynamic> json) =>
      _$TaskStateSynchronizationPayloadFromJson(json);

  @override
  String get eventName => 'task_state_synchronization';
}
