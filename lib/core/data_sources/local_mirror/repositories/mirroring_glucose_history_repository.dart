import '../../../domain/model/glucose.dart';
import '../../domain/glucose_history_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringGlucoseHistoryRepository implements GlucoseHistoryRepository {
  MirroringGlucoseHistoryRepository({
    required this._delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _mirroring = LocalRepositoryMirroring(mirrorWriter);

  final GlucoseHistoryRepository _delegate;
  final LocalRepositoryMirroring _mirroring;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return _mirroring.glucose(
      read: () => _delegate.fetchGlucoseBetween(start, end),
      extract: (readings) => readings,
      operation: 'Glucose history',
    );
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    return _mirroring.glucose(
      read: () => _delegate.fetchRecentGlucose(limit),
      extract: (readings) => readings,
      operation: 'Glucose history',
    );
  }
}
