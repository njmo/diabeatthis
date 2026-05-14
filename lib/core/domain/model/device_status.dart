import 'package:freezed_annotation/freezed_annotation.dart';

part 'device_status.freezed.dart';
part 'device_status.g.dart';

@JsonEnum(valueField: 'storageValue')
enum DeviceStatusSource {
  cloud('cloud'),
  aaps('aaps');

  const DeviceStatusSource(this.storageValue);

  final String storageValue;

  static DeviceStatusSource fromStorage(String? value) {
    return DeviceStatusSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => DeviceStatusSource.cloud,
    );
  }
}

@freezed
abstract class DeviceStatus with _$DeviceStatus {
  const factory DeviceStatus({
    required String? externalId,
    required DeviceStatusSource source,
    required DateTime date,
    required double iob,
    required double basalIob,
    required double bolusIob,
    required double insulinActivity,
    required double cob,
    required String tick,
    required int bg,
    required double carbsReq,
    required int carbsReqWithin,
    required double sensitivityRatio,
    required double isfMgdlForCarbs,
    required double baseBasalRate,
    required int tempBasalRemainingMinutes,
    required double lastBolusAmount,
    required String lastBolusAt,
  }) = _DeviceStatus;

  factory DeviceStatus.fromJson(Map<String, dynamic> json) =>
      _$DeviceStatusFromJson(json);
}
