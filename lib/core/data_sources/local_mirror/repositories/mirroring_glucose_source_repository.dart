import '../../../domain/model/glucose.dart';
import '../../../logger/logger.dart';
import '../../domain/glucose_source_repository.dart';
import '../services/local_mirror_writer.dart';

class MirroringGlucoseSourceRepository
    with Logging
    implements GlucoseSourceRepository {
  const MirroringGlucoseSourceRepository({
    required GlucoseSourceRepository delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _delegate = delegate,
       _mirrorWriter = mirrorWriter;

  final GlucoseSourceRepository _delegate;
  final LocalMirrorWriter _mirrorWriter;

  @override
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after) async {
    final readings = await _delegate.fetchGlucoseAfter(after);
    await _mirror(readings);
    return readings;
  }

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    final readings = await _delegate.fetchGlucoseBetween(start, end);
    await _mirror(readings);
    return readings;
  }

  @override
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day) async {
    final readings = await _delegate.fetchGlucoseOnDay(day);
    await _mirror(readings);
    return readings;
  }

  @override
  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit) async {
    final readings = await _delegate.fetchLastGlucoseWithLimit(limit);
    await _mirror(readings);
    return readings;
  }

  Future<void> _mirror(List<Glucose> readings) async {
    try {
      await _mirrorWriter.mirrorGlucose(readings);
    } catch (e, st) {
      logW('Glucose local mirror write failed: $e\n$st');
    }
  }
}
