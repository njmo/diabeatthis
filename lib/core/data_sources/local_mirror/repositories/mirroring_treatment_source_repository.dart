import '../../../domain/model/treatment_base.dart';
import '../../config/data_source_config.dart';
import '../../domain/treatment_source_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringTreatmentSourceRepository implements TreatmentSourceRepository {
  MirroringTreatmentSourceRepository({
    required this._delegate,
    required LocalMirrorWriter mirrorWriter,
    required this._source,
  }) : _mirroring = LocalRepositoryMirroring(mirrorWriter);

  final TreatmentSourceRepository _delegate;
  final LocalRepositoryMirroring _mirroring;
  final TreatmentsSource _source;

  @override
  Future<List<Treatment>> pollTreatments() {
    return _mirroring.treatments(
      read: _delegate.pollTreatments,
      extract: (treatments) => treatments,
      source: _source,
      operation: 'Treatment',
    );
  }
}
