import 'package:drift/drift.dart';

import '../../../domain/model/device_status.dart' as domain;
import '../../../drift/database_impl.dart';

extension DeviceStatusDriftMapper on domain.DeviceStatus {
  DeviceStatusCompanion toDriftCompanion() {
    return DeviceStatusCompanion.insert(
      source: source.storageValue,
      externalId: externalId != null
          ? Value(externalId!)
          : id > 0
          ? Value(id.toString())
          : const Value.absent(),
      recordedAt: date.millisecondsSinceEpoch,
      bg: Value(bg),
      tick: Value(tick),
      iob: Value(iob),
      basalIob: Value(basalIob),
      bolusIob: Value(bolusIob),
      insulinActivity: Value(insulinActivity),
      cob: Value(cob),
      carbsReq: Value(carbsReq),
      carbsReqWithin: Value(carbsReqWithin),
      sensitivityRatio: Value(sensitivityRatio),
      isfMgdlForCarbs: Value(isfMgdlForCarbs),
      baseBasalRate: Value(baseBasalRate),
      tempBasalRemainingMinutes: Value(tempBasalRemainingMinutes),
      lastBolusAmount: Value(lastBolusAmount),
      lastBolusAt: Value(lastBolusAt),
    );
  }
}
