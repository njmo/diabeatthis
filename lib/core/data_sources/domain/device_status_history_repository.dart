import '../../domain/model/device_status.dart';

abstract class DeviceStatusHistoryRepository {
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  );

  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before);
}
