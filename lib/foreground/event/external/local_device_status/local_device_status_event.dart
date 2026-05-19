import '../../../../core/data_sources/nightscout/dto/device_status_dto.dart';
import '../../../../core/data_sources/nightscout/mappers/device_status_mapper.dart';
import '../../../../core/domain/model/device_status.dart';

class LocalDeviceStatusEvent {
  const LocalDeviceStatusEvent({required this.data});

  final DeviceStatus data;

  factory LocalDeviceStatusEvent.fromJson(Map<String, dynamic> json) {
    final dto = DeviceStatusDto.fromJson(json);

    return LocalDeviceStatusEvent(
      data: dto.toDomain(source: DeviceStatusSource.aaps),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': data.externalId,
      'created_at': data.date.toIso8601String(),
      'openaps': {
        'suggested': {
          'IOB': data.iob,
          'COB': data.cob,
          'tick': data.tick,
          'bg': data.bg,
          'carbsReq': data.carbsReq,
          'carbsReqWithin': data.carbsReqWithin,
          'sensitivityRatio': data.sensitivityRatio,
          'isfMgdlForCarbs': data.isfMgdlForCarbs,
        },
        'iob': {
          'iob': data.iob,
          'basaliob': data.basalIob,
          'activity': data.insulinActivity,
        },
      },
      'pump': {
        'extended': {
          'BaseBasalRate': data.baseBasalRate,
          'TempBasalRemaining': data.tempBasalRemainingMinutes,
          'LastBolusAmount': data.lastBolusAmount,
          'LastBolus': data.lastBolusAt,
        },
      },
    };
  }
}
