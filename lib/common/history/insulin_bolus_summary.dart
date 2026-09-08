import '../../core/domain/model/correction_bolus.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treatment_base.dart';

/// Recorded positive insulin deliveries within an inclusive observation window.
class InsulinBolusSummary {
  final int manualCount;
  final double manualUnits;
  final int otherCount;
  final double otherUnits;

  const InsulinBolusSummary({
    required this.manualCount,
    required this.manualUnits,
    required this.otherCount,
    required this.otherUnits,
  });

  factory InsulinBolusSummary.fromTreatments({
    required Iterable<Treatment> treatments,
    required DateTime start,
    required DateTime end,
  }) {
    var manualCount = 0;
    var manualUnits = 0.0;
    var otherCount = 0;
    var otherUnits = 0.0;
    for (final treatment in treatments) {
      final time = treatment.createdAt;
      if (!treatment.isValid ||
          time == null ||
          time.isBefore(start) ||
          time.isAfter(end)) {
        continue;
      }
      if (treatment is ManualBolus &&
          treatment.insulin.isFinite &&
          treatment.insulin > 0) {
        manualCount++;
        manualUnits += treatment.insulin;
      } else if (treatment is CorrectionBolus &&
          treatment.insulin.isFinite &&
          treatment.insulin > 0) {
        otherCount++;
        otherUnits += treatment.insulin;
      }
    }
    return InsulinBolusSummary(
      manualCount: manualCount,
      manualUnits: manualUnits,
      otherCount: otherCount,
      otherUnits: otherUnits,
    );
  }

  int get count => manualCount + otherCount;
  double get units => manualUnits + otherUnits;
}
