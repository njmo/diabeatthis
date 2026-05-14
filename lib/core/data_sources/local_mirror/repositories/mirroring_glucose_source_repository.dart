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
  Future<Glucose?> pollGlucose() async {
    final reading = await _delegate.pollGlucose();
    if (reading != null) {
      await _mirror([reading]);
    }
    return reading;
  }

  Future<void> _mirror(List<Glucose> readings) async {
    try {
      await _mirrorWriter.mirrorGlucose(readings);
    } catch (e, st) {
      logW('Glucose local mirror write failed: $e\n$st');
    }
  }
}
