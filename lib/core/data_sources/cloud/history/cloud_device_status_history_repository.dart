import '../../../domain/model/device_status.dart';
import '../../domain/device_status_history_repository.dart';
import '../../nightscout/repository/nightscout_repository.dart';

class CloudDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  const CloudDeviceStatusHistoryRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return _nightscoutRepository.fetchDeviceStatusBetween(start, end);
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    return _nightscoutRepository.fetchLastDeviceStatusBefore(before);
  }
}
