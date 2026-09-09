import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';

/// Groups chronological calculator neighbours without deleting raw data.
class BolusWizardGrouping {
  final Set<Treatment> relatedRecords;

  BolusWizardGrouping(Iterable<Treatment> treatments)
    : relatedRecords = <Treatment>{} {
    final records =
        treatments.where((record) => record.createdAt != null).toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
    for (var index = 0; index < records.length; index++) {
      final wizard = records[index];
      if (wizard is! BolusWizard || !wizard.isValid) continue;
      final previous = index > 0 ? records[index - 1] : null;
      final next = index + 1 < records.length ? records[index + 1] : null;
      if (previous is Treat) {
        _match(previous, wizard.carbs, previous.carbs.toDouble());
      }
      if (next is ManualBolus) {
        _match(next, wizard.insulin, next.insulin);
      }
    }
  }

  void _match(Treatment record, double expectedAmount, double recordedAmount) {
    // Keep differing amounts visible rather than replacing them with calculator values.
    if (record.isValid &&
        expectedAmount.isFinite &&
        expectedAmount > 0 &&
        recordedAmount.isFinite &&
        (recordedAmount - expectedAmount).abs() <= 0.001) {
      relatedRecords.add(record);
    }
  }

  bool isRelated(Treatment treatment) => relatedRecords.contains(treatment);
}
