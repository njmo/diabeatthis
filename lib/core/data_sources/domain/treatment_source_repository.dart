import '../../domain/model/treatment_base.dart';

abstract class TreatmentSourceRepository {
  Future<List<Treatment>> pollTreatments();
}
