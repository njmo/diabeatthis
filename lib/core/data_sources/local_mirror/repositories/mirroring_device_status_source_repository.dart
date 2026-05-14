import '../../../domain/model/device_status.dart';
import '../../../logger/logger.dart';
import '../../domain/device_status_source_repository.dart';
import '../services/local_mirror_writer.dart';

class MirroringDeviceStatusSourceRepository
    with Logging
    implements DeviceStatusSourceRepository {
  const MirroringDeviceStatusSourceRepository({
    required DeviceStatusSourceRepository delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _delegate = delegate,
       _mirrorWriter = mirrorWriter;

  final DeviceStatusSourceRepository _delegate;
  final LocalMirrorWriter _mirrorWriter;

  @override
  Future<DeviceStatus> pollDeviceStatus() async {
    final status = await _delegate.pollDeviceStatus();
    await _mirror([status]);
    return status;
  }

  Future<void> _mirror(Iterable<DeviceStatus> statuses) async {
    try {
      await _mirrorWriter.mirrorDeviceStatuses(statuses);
    } catch (e, st) {
      logW('Device status local mirror write failed: $e\n$st');
    }
  }
}
