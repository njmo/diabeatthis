import 'package:drift/drift.dart';

import '../../../domain/model/device_status.dart';
import '../../../drift/database_impl.dart';
import '../../config/data_source_config.dart';

extension LocalDeviceStatusMirrorMapper on DeviceStatus {
  LocalDeviceStatusCompanion toLocalMirrorCompanion(EventSource source) {
    return LocalDeviceStatusCompanion.insert(
      source: source.storageValue,
      externalId: id > 0 ? Value(id.toString()) : const Value.absent(),
      recordedAt: date.millisecondsSinceEpoch,
      bg: Value(bg),
      tick: Value(tick),
      iob: Value(iob),
      cob: Value(cob),
    );
  }
}
