import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_status_dto.freezed.dart';
part 'device_status_dto.g.dart';

@freezed
abstract class DeviceStatusDto  with _$DeviceStatusDto {

  const factory DeviceStatusDto ({
    required String created_at,
    Map<String, dynamic>? openaps,
  }) = _DeviceStatusDto;

  factory DeviceStatusDto .fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusDtoFromJson(json);
}
