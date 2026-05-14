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
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async {
    final statuses = await _delegate.fetchDeviceStatusBetween(start, end);
    await _mirror(statuses);
    return statuses;
  }

  @override
  Future<DeviceStatus> fetchLastDeviceStatus() async {
    final status = await _delegate.fetchLastDeviceStatus();
    await _mirror([status]);
    return status;
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async {
    final status = await _delegate.fetchLastDeviceStatusBefore(before);
    if (status != null) {
      await _mirror([status]);
    }
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
