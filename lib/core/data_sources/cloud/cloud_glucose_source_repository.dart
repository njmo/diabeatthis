import '../../domain/model/glucose.dart';
import '../domain/glucose_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';

class CloudGlucoseSourceRepository implements GlucoseSourceRepository {
  const CloudGlucoseSourceRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<Glucose?> pollGlucose() async {
    final readings = await _nightscoutRepository.fetchLastGlucoseWithLimit(1);
    return readings.firstOrNull;
  }
}
