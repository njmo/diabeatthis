import '../../../domain/model/glucose.dart';
import '../../domain/glucose_source_repository.dart';
import '../services/local_mirror_writer.dart';
import 'local_repository_mirroring.dart';

class MirroringGlucoseSourceRepository implements GlucoseSourceRepository {
  MirroringGlucoseSourceRepository({
    required this._delegate,
    required LocalMirrorWriter mirrorWriter,
  }) : _mirroring = LocalRepositoryMirroring(mirrorWriter);

  final GlucoseSourceRepository _delegate;
  final LocalRepositoryMirroring _mirroring;

  @override
  Future<Glucose?> pollGlucose() {
    return _mirroring.glucose(
      read: _delegate.pollGlucose,
      extract: (reading) => reading == null ? <Glucose>[] : [reading],
      operation: 'Glucose',
    );
  }
}
