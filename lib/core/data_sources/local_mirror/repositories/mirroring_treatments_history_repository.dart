import '../../../domain/model/treatment_base.dart';
import '../../config/data_source_config.dart';
import '../../domain/treatments_history_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringTreatmentsHistoryRepository
    implements TreatmentsHistoryRepository {
  MirroringTreatmentsHistoryRepository({
    required TreatmentsHistoryRepository delegate,
    required LocalMirrorWriter mirrorWriter,
    required TreatmentsSource source,
  }) : _delegate = delegate,
       _mirroring = LocalRepositoryMirroring(mirrorWriter),
       _source = source;

  final TreatmentsHistoryRepository _delegate;
  final LocalRepositoryMirroring _mirroring;
  final TreatmentsSource _source;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    return _mirroring.treatments(
      read: () => _delegate.fetchTreatmentsBetween(start, end),
      extract: (treatments) => treatments,
      source: _source,
      operation: 'Treatments history',
    );
  }
}
