import '../../domain/model/device_status.dart';

abstract class DeviceStatusSourceRepository {
  Future<DeviceStatus> pollDeviceStatus();
}
