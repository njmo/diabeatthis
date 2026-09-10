import 'dart:convert';

import '../../../domain/model/device_status.dart';
import '../dto/device_status_dto.dart';

extension DeviceStatusMapper on DeviceStatusDto {
  DeviceStatus toDomain({
    DeviceStatusSource source = DeviceStatusSource.cloud,
  }) {
    final suggested =
        (openaps?['suggested'] as Map<String, dynamic>?) ?? const {};
    final iobData = _iobData(openaps?['iob']);
    final totalIob =
        (iobData['iob'] as num?)?.toDouble() ??
        (suggested['IOB'] as num?)?.toDouble();
    final basalIob = (iobData['basaliob'] as num?)?.toDouble() ?? 0;
    final pumpExtended = _mapValue(pump?['extended']);

    return DeviceStatus(
      externalId: id,
      source: source,
      date: DateTime.parse(createdAt).toLocal(),
      iob: totalIob ?? 0,
      hasIob: totalIob != null,
      hasCob: suggested['COB'] is num,
      basalIob: basalIob,
      bolusIob: (totalIob ?? 0) - basalIob,
      insulinActivity: (iobData['activity'] as num?)?.toDouble() ?? 0,
      hasInsulinActivity: iobData['activity'] is num,
      insulinActivityAt: iobData['time'] is String
          ? DateTime.tryParse(iobData['time'] as String)
          : null,
      aapsPredictionsJson: suggested['predBGs'] is Map
          ? jsonEncode({
              'timestamp': suggested['timestamp'],
              'predBGs': suggested['predBGs'],
            })
          : null,
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
