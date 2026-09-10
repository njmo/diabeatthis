import '../../../../core/data_sources/nightscout/dto/device_status_dto.dart';
import '../../../../core/data_sources/nightscout/mappers/device_status_mapper.dart';
import '../../../../core/domain/model/aaps_prediction_snapshot.dart';
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
        'enacted': {
          if (data.enactedBasalAt != null)
            'timestamp': data.enactedBasalAt!.toIso8601String(),
          if (data.enactedBasalRate != null) 'rate': data.enactedBasalRate,
          if (data.enactedBasalDurationMinutes != null)
            'duration': data.enactedBasalDurationMinutes,
          if (data.enactedBasalReceived != null)
            'received': data.enactedBasalReceived,
        },
        'suggested': {
          ...?AapsPredictionSnapshot.decode(data.aapsPredictionsJson)?.toJson(),
          if (data.hasIob) 'IOB': data.iob,
          if (data.hasCob) 'COB': data.cob,
          'tick': data.tick,
          'bg': data.bg,
          'carbsReq': data.carbsReq,
          'carbsReqWithin': data.carbsReqWithin,
          'sensitivityRatio': data.sensitivityRatio,
          'isfMgdlForCarbs': data.isfMgdlForCarbs,
        },
        'iob': {
          if (data.hasIob) 'iob': data.iob,
          'basaliob': data.basalIob,
          if (data.hasInsulinActivity) 'activity': data.insulinActivity,
          if (data.insulinActivityAt != null)
            'time': data.insulinActivityAt!.toIso8601String(),
        },
      },
      'pump': {
        if (data.basalObservedAt != null)
          'clock': data.basalObservedAt!.toIso8601String(),
        'extended': {
          'BaseBasalRate': data.baseBasalRate,
          if (data.tempBasalAbsoluteRate != null)
            'TempBasalAbsoluteRate': data.tempBasalAbsoluteRate,
          if (data.tempBasalStartedAt != null)
            'TempBasalStart': data.tempBasalStartedAt,
          'TempBasalRemaining': data.tempBasalRemainingMinutes,
          'LastBolusAmount': data.lastBolusAmount,
          'LastBolus': data.lastBolusAt,
        },
      },
    };
  }
}
