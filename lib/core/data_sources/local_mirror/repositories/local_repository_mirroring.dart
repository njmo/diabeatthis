import '../../../domain/model/device_status.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../logger/logger.dart';
import '../../config/data_source_config.dart';
import '../services/local_mirror_writer.dart';

class LocalRepositoryMirroring with Logging {
  const LocalRepositoryMirroring(this._writer);

  final LocalMirrorWriter _writer;

  Future<T> glucose<T>({
    required Future<T> Function() read,
    required Iterable<Glucose> Function(T result) extract,
    required String operation,
  }) {
    return mirrorAfter(
      read: read,
      write: (result) => _writer.mirrorGlucose(extract(result)),
      operation: operation,
    );
  }

  Future<T> treatments<T>({
    required Future<T> Function() read,
    required Iterable<Treatment> Function(T result) extract,
    required EventSource source,
    required String operation,
  }) {
    return mirrorAfter(
      read: read,
      write: (result) => _writer.mirrorTreatments(extract(result), source),
      operation: operation,
    );
  }

  Future<T> deviceStatuses<T>({
    required Future<T> Function() read,
    required Iterable<DeviceStatus> Function(T result) extract,
    required String operation,
  }) {
    return mirrorAfter(
      read: read,
      write: (result) => _writer.mirrorDeviceStatuses(extract(result)),
      operation: operation,
    );
  }

  Future<T> mirrorAfter<T>({
    required Future<T> Function() read,
    required Future<void> Function(T result) write,
    required String operation,
  }) async {
    final result = await read();

    try {
      await write(result);
    } catch (e, st) {
      logW('$operation local mirror write failed: $e\n$st');
    }

    return result;
  }
}
