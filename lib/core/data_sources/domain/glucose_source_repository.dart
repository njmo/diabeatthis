import '../../domain/model/glucose.dart';

abstract class GlucoseSourceRepository {
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day);

  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end);

  Future<List<Glucose>> fetchGlucoseAfter(DateTime after);

  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit);
}
