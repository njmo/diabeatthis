import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';

/// Groups chronological calculator neighbours without deleting raw data.
class BolusWizardGrouping {
  // This matches records from one calculator submission, not the meal window.
  // Keep uncertain carbohydrates visible rather than hiding a separate intake.
  static const carbSubmissionWindow = Duration(seconds: 10);

  final Set<Treatment> relatedRecords;

  BolusWizardGrouping(Iterable<Treatment> treatments)
    : relatedRecords = <Treatment>{} {
    final timestampGroups = <DateTime, List<Treatment>>{};
    for (final record in treatments) {
      final time = record.createdAt;
      if (time != null) {
        timestampGroups.putIfAbsent(time, () => []).add(record);
      }
    }
    final ambiguous = <Treatment>{};
    for (final group in timestampGroups.values) {
      if (group.length <= 1) continue;
      final types = group.map(_submissionOrder).toSet();
      if (types.contains(3) || types.length != group.length) {
        ambiguous.addAll(group);
      }
    }
    final records = timestampGroups.values.expand((group) => group).toList()
      ..sort((a, b) {
        final timeOrder = a.createdAt!.compareTo(b.createdAt!);
        return timeOrder != 0
            ? timeOrder
            : _submissionOrder(a).compareTo(_submissionOrder(b));
      });
    for (var index = 0; index < records.length; index++) {
      final wizard = records[index];
      if (wizard is! BolusWizard ||
          !wizard.isValid ||
          ambiguous.contains(wizard)) {
        continue;
      }
      final previous = index > 0 ? records[index - 1] : null;
      final next = index + 1 < records.length ? records[index + 1] : null;
      if (previous is Treat &&
          !ambiguous.contains(previous) &&
          wizard.createdAt.difference(previous.createdAt) <=
              carbSubmissionWindow) {
        _match(previous, wizard.carbs, previous.carbs.toDouble());
      }
      if (next is ManualBolus && !ambiguous.contains(next)) {
        _match(next, wizard.insulin, next.insulin);
      }
    }
  }

  // Equal timestamps may arrive in different orders from local and remote history.
  static int _submissionOrder(Treatment record) => switch (record) {
    Treat() => 0,
    BolusWizard() => 1,
    ManualBolus() => 2,
    _ => 3,
  };

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
