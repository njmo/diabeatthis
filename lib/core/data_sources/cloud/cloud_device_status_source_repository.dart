import '../../domain/model/device_status.dart';
import '../domain/device_status_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';

class CloudDeviceStatusSourceRepository
    implements DeviceStatusSourceRepository {
  const CloudDeviceStatusSourceRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<DeviceStatus> pollDeviceStatus() {
    return _nightscoutRepository.fetchLastDeviceStatus();
  }
}
