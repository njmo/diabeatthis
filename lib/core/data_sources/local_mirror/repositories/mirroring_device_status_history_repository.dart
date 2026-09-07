import '../../../domain/model/device_status.dart';
import '../../domain/device_status_history_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringDeviceStatusHistoryRepository
    implements DeviceStatusHistoryRepository {
  MirroringDeviceStatusHistoryRepository({
    required this._delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _mirroring = LocalRepositoryMirroring(mirrorWriter);

  final DeviceStatusHistoryRepository _delegate;
  final LocalRepositoryMirroring _mirroring;

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) {
    return _mirroring.deviceStatuses(
      read: () => _delegate.fetchDeviceStatusBetween(start, end),
      extract: (statuses) => statuses,
      operation: 'Device status history',
    );
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) {
    return _mirroring.deviceStatuses(
      read: () => _delegate.fetchLastDeviceStatusBefore(before),
      extract: (status) => status == null ? <DeviceStatus>[] : [status],
      operation: 'Device status history',
    );
  }
}
