import '../../domain/model/glucose.dart';

abstract class GlucoseHistoryRepository {
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end);

  Future<List<Glucose>> fetchRecentGlucose(int limit);
}
