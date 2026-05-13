import '../../domain/model/meal.dart';
import '../../domain/model/temporary_target.dart';
import '../../domain/model/treatment_base.dart';

abstract class TreatmentSourceRepository {
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsAfter(DateTime after);

  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end);

  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after);

  Future<TemporaryTarget> fetchLastTemporaryTarget();

  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id);
}
