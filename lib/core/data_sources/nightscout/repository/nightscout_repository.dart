import '../../../domain/model/device_status.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/meal.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treatment_base.dart';

abstract class NightscoutRepository {
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsAfter(DateTime after);
  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end);
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after);
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day);
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end);
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after);
  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit);
  Future<DeviceStatus> fetchLastDeviceStatus();
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  );
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before);
  Future<TemporaryTarget> fetchLastTemporaryTarget();
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id);
  Future<Duration?> getLatestSensorChangeAge();
  Future<Duration?> getLatestInsulinChangeAge();
}
