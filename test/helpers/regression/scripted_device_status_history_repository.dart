import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedDeviceStatusHistoryRepository extends Fake
    implements DeviceStatusHistoryRepository {
  final ScriptedRead<List<DeviceStatus>> between;
  final ScriptedRead<DeviceStatus?> before;
  ScriptedDeviceStatusHistoryRepository(this.between, this.before);

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime at) =>
      before([at]);

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) => between([start, end]);
}
