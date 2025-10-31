import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_status.freezed.dart';

@freezed
abstract class DeviceStatus with _$DeviceStatus {
  const factory DeviceStatus({
    required int id,
    required DateTime date,
    required double iob,
    required double cob,
    required String tick,
    required int bg,
  }) = _DeviceStatus;
}
