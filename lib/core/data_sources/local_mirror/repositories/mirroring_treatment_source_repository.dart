import '../../../domain/model/treatment_base.dart';
import '../../../logger/logger.dart';
import '../../config/data_source_config.dart';
import '../../domain/treatment_source_repository.dart';
import '../services/local_mirror_writer.dart';

class MirroringTreatmentSourceRepository
    with Logging
    implements TreatmentSourceRepository {
  const MirroringTreatmentSourceRepository({
    required TreatmentSourceRepository delegate,
    required LocalMirrorWriter mirrorWriter,
    required EventSource source,
  }) : _delegate = delegate,
       _mirrorWriter = mirrorWriter,
       _source = source;

  final TreatmentSourceRepository _delegate;
  final LocalMirrorWriter _mirrorWriter;
  final EventSource _source;

  @override
  Future<List<Treatment>> pollTreatments() async {
    final treatments = await _delegate.pollTreatments();
    await _mirror(treatments);
    return treatments;
  }

  Future<void> _mirror(Iterable<Treatment> treatments) async {
    try {
      await _mirrorWriter.mirrorTreatments(treatments, _source);
    } catch (e, st) {
      logW('Treatment local mirror write failed: $e\n$st');
    }
  }
}
