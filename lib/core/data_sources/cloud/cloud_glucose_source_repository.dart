import '../../domain/model/glucose.dart';
import '../domain/glucose_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';

class CloudGlucoseSourceRepository implements GlucoseSourceRepository {
  const CloudGlucoseSourceRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after) {
    return _nightscoutRepository.fetchGlucoseAfter(after);
  }

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return _nightscoutRepository.fetchGlucoseBetween(start, end);
  }

  @override
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day) {
    return _nightscoutRepository.fetchGlucoseOnDay(day);
  }

  @override
  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit) {
    return _nightscoutRepository.fetchLastGlucoseWithLimit(limit);
  }
}
