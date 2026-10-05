import 'package:freezed_annotation/freezed_annotation.dart';

import '../../task_event_payload.dart';

part 'task_open_low_treatment_payload.freezed.dart';
part 'task_open_low_treatment_payload.g.dart';

@freezed
abstract class TaskOpenLowTreatmentPayload
    with _$TaskOpenLowTreatmentPayload, TaskEventPayload {
  const TaskOpenLowTreatmentPayload._();

  const factory TaskOpenLowTreatmentPayload() = _TaskOpenLowTreatmentPayload;

  factory TaskOpenLowTreatmentPayload.fromJson(Map<String, dynamic> json) =>
      _$TaskOpenLowTreatmentPayloadFromJson(json);

  @override
  String get eventName => 'task_open_low_treatment';
}
