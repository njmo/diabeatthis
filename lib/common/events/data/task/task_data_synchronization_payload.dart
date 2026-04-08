import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../../task_event_payload.dart';

part 'task_data_synchronization_payload.freezed.dart';
part 'task_data_synchronization_payload.g.dart';

@freezed
abstract class TaskDataSynchronizationPayload
    with _$TaskDataSynchronizationPayload, TaskEventPayload {
  const TaskDataSynchronizationPayload._();

  const factory TaskDataSynchronizationPayload.glucose({
    required Glucose data
  }) = TaskGlucoseSynchronization;

  const factory TaskDataSynchronizationPayload.target({
    required TemporaryTarget data
  }) = TaskTargetSynchronization;

  const factory TaskDataSynchronizationPayload.deviceStatus({
    required DeviceStatus data
  }) = TaskDeviceStatusSynchronization;

  const factory TaskDataSynchronizationPayload.list({
    required List<TaskDataSynchronizationPayload> data
  }) = TaskListSynchronization;

  factory TaskDataSynchronizationPayload.fromJson(Map<String, dynamic> json) =>
      _$TaskDataSynchronizationPayloadFromJson(json);

  @override
  String get eventName => 'task_data_synchronization';
}