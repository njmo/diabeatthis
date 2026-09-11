import '../../../../core/domain/model/treat.dart';
import 'recorded_low_treatment.dart';

class LowTreatmentReviewEntry {
  final Treat? event;
  final RecordedLowTreatment? recorded;
  final bool dismissed;
  final bool ambiguous;
  final bool staleDecision;
  const LowTreatmentReviewEntry({
    this.event,
    this.recorded,
    this.dismissed = false,
    this.ambiguous = false,
    this.staleDecision = false,
  });
  bool get isPending => event != null && recorded == null && !dismissed;
  bool get canReset => event != null && (staleDecision || !isPending);

  DateTime get occurredAt => event?.createdAt ?? recorded!.eatenAt;
}
