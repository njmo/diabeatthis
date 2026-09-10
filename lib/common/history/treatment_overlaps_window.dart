import '../../core/domain/model/stress_event_treatment.dart';
import '../../core/domain/model/treatment_base.dart';

/// Treatment repositories return stress intervals overlapping the requested
/// window, even when they started earlier. Other treatments use event time.
bool treatmentOverlapsWindow(
  Treatment treatment,
  DateTime start,
  DateTime end,
) {
  final at = treatment.createdAt;
  if (at == null || at.isAfter(end)) return false;
  if (!at.isBefore(start)) return true;
  return treatment is StressEventTreatment &&
      treatment.event.endedAt != null &&
      !treatment.event.endedAt!.isBefore(start);
}
