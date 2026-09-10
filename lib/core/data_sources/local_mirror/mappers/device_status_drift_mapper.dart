import 'package:drift/drift.dart';

import '../../../domain/model/device_status.dart' as domain;
import '../../../drift/database_impl.dart';

extension DeviceStatusDriftMapper on domain.DeviceStatus {
  DeviceStatusCompanion toCompanion() {
    return DeviceStatusCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : const Value.absent(),
      createdAt: Value(date.millisecondsSinceEpoch),
      bg: Value(bg),
      tick: Value(tick),
      iob: Value(hasIob ? iob : null),
      basalIob: Value(basalIob),
      bolusIob: Value(bolusIob),
      insulinActivity: Value(hasInsulinActivity ? insulinActivity : null),
      insulinActivityAt: Value(insulinActivityAt?.millisecondsSinceEpoch),
      aapsPredictionsJson: Value(aapsPredictionsJson),
      cob: Value(hasCob ? cob : null),
      carbsReq: Value(carbsReq),
      carbsReqWithin: Value(carbsReqWithin),
      sensitivityRatio: Value(sensitivityRatio),
      isfMgdlForCarbs: Value(isfMgdlForCarbs),
      basalObservedAt: Value(basalObservedAt?.millisecondsSinceEpoch),
      tempBasalAbsoluteRate: Value(tempBasalAbsoluteRate),
      tempBasalStartedAt: Value(tempBasalStartedAt),
      enactedBasalRate: Value(enactedBasalRate),
      enactedBasalAt: Value(enactedBasalAt?.millisecondsSinceEpoch),
      enactedBasalDurationMinutes: Value(enactedBasalDurationMinutes),
      enactedBasalReceived: Value(enactedBasalReceived),
      baseBasalRate: Value(baseBasalRate),
      tempBasalRemainingMinutes: Value(tempBasalRemainingMinutes),
      lastBolusAmount: Value(lastBolusAmount),
      lastBolusAt: Value(lastBolusAt),
    );
  }
}

extension DeviceStatusDomainMapper on DeviceStatusData {
  domain.DeviceStatus toDomain() {
    return domain.DeviceStatus(
      externalId: externalId,
      source: domain.DeviceStatusSource.fromStorage(source),
      date: DateTime.fromMillisecondsSinceEpoch(createdAt),
      iob: iob ?? 0,
      hasIob: iob != null,
      hasCob: cob != null,
      basalIob: basalIob ?? 0,
      bolusIob: bolusIob ?? 0,
      insulinActivity: insulinActivity ?? 0,
      hasInsulinActivity: insulinActivity != null,
      insulinActivityAt: insulinActivityAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(insulinActivityAt!),
      aapsPredictionsJson: aapsPredictionsJson,
      cob: cob ?? 0,
      tick: tick ?? '',
      bg: bg ?? 0,
      carbsReq: carbsReq ?? 0,
      carbsReqWithin: carbsReqWithin ?? 0,
      sensitivityRatio: sensitivityRatio ?? 0,
      isfMgdlForCarbs: isfMgdlForCarbs ?? 0,
      basalObservedAt: basalObservedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(basalObservedAt!, isUtc: true),
      tempBasalAbsoluteRate: tempBasalAbsoluteRate,
      tempBasalStartedAt: tempBasalStartedAt,
      enactedBasalRate: enactedBasalRate,
      enactedBasalAt: enactedBasalAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(enactedBasalAt!, isUtc: true),
      enactedBasalDurationMinutes: enactedBasalDurationMinutes,
      enactedBasalReceived: enactedBasalReceived,
      baseBasalRate: baseBasalRate ?? 0,
      tempBasalRemainingMinutes: tempBasalRemainingMinutes ?? 0,
      lastBolusAmount: lastBolusAmount ?? 0,
      lastBolusAt: lastBolusAt ?? '',
    );
  }
}
