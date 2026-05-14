import '../../../domain/model/treatment_base.dart';
import '../../domain/treatments_history_repository.dart';
import '../../nightscout/repository/nightscout_repository.dart';

class CloudTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  const CloudTreatmentsHistoryRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    return _nightscoutRepository.fetchTreatmentsBetween(start, end);
  }
}
