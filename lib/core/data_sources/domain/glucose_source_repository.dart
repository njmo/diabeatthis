import '../../domain/model/glucose.dart';

abstract class GlucoseSourceRepository {
  Future<Glucose?> pollGlucose();
}
