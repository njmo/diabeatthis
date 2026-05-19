import 'package:freezed_annotation/freezed_annotation.dart';

import '../local_device_status/local_device_status_event.dart';
import '../local_glucose/local_glucose_event.dart';
import '../local_treatments/local_treatments_event.dart';

part 'native_receiver_event.freezed.dart';
part 'native_receiver_event.g.dart';

@Freezed(unionKey: 'kind', unionValueCase: FreezedUnionCase.snake)
sealed class NativeReceiverEvent with _$NativeReceiverEvent {
  const NativeReceiverEvent._();

  const factory NativeReceiverEvent.glucose({required LocalGlucoseEvent data}) =
      NativeReceiverGlucoseEvent;

  const factory NativeReceiverEvent.deviceStatus({
    required LocalDeviceStatusEvent data,
  }) = NativeReceiverDeviceStatusEvent;

  const factory NativeReceiverEvent.treatments({
    required LocalTreatmentsEvent data,
  }) = NativeReceiverTreatmentsEvent;

  factory NativeReceiverEvent.fromJson(Map<String, dynamic> json) =>
      _$NativeReceiverEventFromJson(json);
}
