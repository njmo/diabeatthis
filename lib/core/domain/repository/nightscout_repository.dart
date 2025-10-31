import '../model/device_status.dart';
import '../model/glucose.dart';
import '../model/meal.dart';
import '../model/treatment_base.dart';

abstract class NightscoutRepository {
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsOnDay(DateTime day);

  Future<List<Meal>> fetchMealsAfter(DateTime after);
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after);
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day);
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after);
  Future<DeviceStatus> fetchLastDeviceStatus();
  Future<Duration?> getLatestSensorChangeAge();
  Future<Duration?> getLatestInsulinChangeAge();
}