import '../../../domain/model/device_status.dart';
import '../dto/device_status_dto.dart';

extension DeviceStatusMapper on DeviceStatusDto {
  DeviceStatus toDomain() {
    final suggested =
        (openaps?['suggested'] as Map<String, dynamic>?) ?? const {};
    final iobData = _iobData(openaps?['iob']);
    final totalIob =
        (iobData['iob'] as num?)?.toDouble() ??
        (suggested['IOB'] as num?)?.toDouble() ??
        0;
    final basalIob = (iobData['basaliob'] as num?)?.toDouble() ?? 0;
    final pumpExtended = _mapValue(pump?['extended']);

    return DeviceStatus(
      externalId: id,
      source: DeviceStatusSource.cloud,
      date: DateTime.parse(createdAt).toLocal(),
      iob: totalIob,
      basalIob: basalIob,
      bolusIob: totalIob - basalIob,
      insulinActivity: (iobData['activity'] as num?)?.toDouble() ?? 0,
      cob: (suggested['COB'] as num?)?.toDouble() ?? 0,
      tick: (suggested['tick'] as String?) ?? '',
      bg: (suggested['bg'] as num?)?.toInt() ?? 0,
      carbsReq: (suggested['carbsReq'] as num?)?.toDouble() ?? 0,
      carbsReqWithin: (suggested['carbsReqWithin'] as num?)?.toInt() ?? 0,
      sensitivityRatio:
          (suggested['sensitivityRatio'] as num?)?.toDouble() ?? 1,
      isfMgdlForCarbs: (suggested['isfMgdlForCarbs'] as num?)?.toDouble() ?? 0,
      baseBasalRate: (pumpExtended?['BaseBasalRate'] as num?)?.toDouble() ?? 0,
      tempBasalRemainingMinutes:
          (pumpExtended?['TempBasalRemaining'] as num?)?.toInt() ?? 0,
      lastBolusAmount:
          (pumpExtended?['LastBolusAmount'] as num?)?.toDouble() ?? 0,
      lastBolusAt: (pumpExtended?['LastBolus'] as String?) ?? '',
    );
  }

  Map<String, dynamic> _iobData(Object? value) {
    if (value case final Map<String, dynamic> map) return map;
    if (value case final List list when list.isNotEmpty) {
      final first = list.first;
      if (first case final Map<String, dynamic> map) return map;
    }
    return const {};
  }

  Map<String, dynamic>? _mapValue(Object? value) {
    if (value case final Map<String, dynamic> map) return map;
    return null;
  }
}
