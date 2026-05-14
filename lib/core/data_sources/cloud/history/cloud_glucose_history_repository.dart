import '../../../domain/model/glucose.dart';
import '../../domain/glucose_history_repository.dart';
import '../../nightscout/repository/nightscout_repository.dart';

class CloudGlucoseHistoryRepository implements GlucoseHistoryRepository {
  const CloudGlucoseHistoryRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) {
    return _nightscoutRepository.fetchGlucoseBetween(start, end);
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) {
    return _nightscoutRepository.fetchLastGlucoseWithLimit(limit);
  }
}
