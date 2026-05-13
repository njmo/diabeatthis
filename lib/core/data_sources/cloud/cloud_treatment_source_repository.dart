import '../../domain/model/meal.dart';
import '../../domain/model/temporary_target.dart';
import '../../domain/model/treatment_base.dart';
import '../domain/treatment_source_repository.dart';
import '../nightscout/repository/nightscout_repository.dart';

class CloudTreatmentSourceRepository implements TreatmentSourceRepository {
  const CloudTreatmentSourceRepository(this._nightscoutRepository);

  final NightscoutRepository _nightscoutRepository;

  @override
  Future<TemporaryTarget> fetchLastTemporaryTarget() {
    return _nightscoutRepository.fetchLastTemporaryTarget();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id) {
    return _nightscoutRepository.fetchLastTemporaryTargetById(id);
  }

  @override
  Future<List<Meal>> fetchMealsAfter(DateTime after) {
    return _nightscoutRepository.fetchMealsAfter(after);
  }

  @override
  Future<List<Meal>> fetchMealsOnDay(DateTime day) {
    return _nightscoutRepository.fetchMealsOnDay(day);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after) {
    return _nightscoutRepository.fetchTreatmentsAfter(after);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end) {
    return _nightscoutRepository.fetchTreatmentsBetween(start, end);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day) {
    return _nightscoutRepository.fetchTreatmentsOnDay(day);
  }
}
