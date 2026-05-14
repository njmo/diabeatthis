import '../../../domain/model/device_status.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../domain/device_status_history_repository.dart';
import '../mappers/device_status_drift_mapper.dart';

class LocalDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  const LocalDeviceStatusHistoryRepository(this._dao);

  final LocalMirrorDao _dao;

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _dao.getDeviceStatusesBetween(start, end);
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async {
    final row = await _dao.getLastDeviceStatusBefore(before);
    return row?.toDomain();
  }
}
