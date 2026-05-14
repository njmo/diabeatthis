import '../../domain/model/treatment_base.dart';

abstract class TreatmentsHistoryRepository {
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end);
}
