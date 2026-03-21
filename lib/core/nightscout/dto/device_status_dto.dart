import 'package:freezed_annotation/freezed_annotation.dart';
// ignore_for_file: invalid_annotation_target
part 'device_status_dto.freezed.dart';
part 'device_status_dto.g.dart';

@freezed
abstract class DeviceStatusDto  with _$DeviceStatusDto {

  const factory DeviceStatusDto ({
    @JsonKey(name: 'created_at') required String createdAt,
    Map<String, dynamic>? openaps,
  }) = _DeviceStatusDto;

  factory DeviceStatusDto .fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusDtoFromJson(json);
}
