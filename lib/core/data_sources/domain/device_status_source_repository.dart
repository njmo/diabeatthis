import '../../domain/model/device_status.dart';

abstract class DeviceStatusSourceRepository {
  Future<DeviceStatus> fetchLastDeviceStatus();

  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  );

  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before);
}
