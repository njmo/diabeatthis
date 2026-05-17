import '../../../domain/model/device_status.dart';
import '../../domain/device_status_source_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringDeviceStatusSourceRepository
    implements DeviceStatusSourceRepository {
  MirroringDeviceStatusSourceRepository({
    required DeviceStatusSourceRepository delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _delegate = delegate,
       _mirroring = LocalRepositoryMirroring(mirrorWriter);

  final DeviceStatusSourceRepository _delegate;
  final LocalRepositoryMirroring _mirroring;

  @override
  Future<DeviceStatus> pollDeviceStatus() {
    return _mirroring.deviceStatuses(
      read: _delegate.pollDeviceStatus,
      extract: (status) => [status],
      operation: 'Device status',
    );
  }
}
