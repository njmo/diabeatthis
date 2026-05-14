import '../../domain/model/bolus_wizard.dart';
import '../../domain/model/temporary_target.dart';
import '../../domain/model/treatment_base.dart';

abstract class TreatmentSourceRepository {
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day);

  Future<List<BolusWizard>> fetchBolusWizardsOnDay(DateTime day);

  Future<List<BolusWizard>> fetchBolusWizardsAfter(DateTime after);

  Future<List<Treatment>> fetchTreatmentsBetween(DateTime start, DateTime end);

  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after);

  Future<TemporaryTarget> fetchLastTemporaryTarget();

  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id);
}
