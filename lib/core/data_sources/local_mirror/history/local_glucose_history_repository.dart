import '../../../domain/model/glucose.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../domain/glucose_history_repository.dart';
import '../mappers/glucose_drift_mapper.dart';

class LocalGlucoseHistoryRepository implements GlucoseHistoryRepository {
  const LocalGlucoseHistoryRepository(this._dao);

  final LocalMirrorDao _dao;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    final rows = await _dao.getGlucoseReadingsBetween(start, end);
    return rows.map((row) => row.toDomain()).toList();
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) async {
    final rows = await _dao.getRecentGlucoseReadings(limit);
    return rows.map((row) => row.toDomain()).toList();
  }
}
