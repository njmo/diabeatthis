import '../../../../core/domain/model/stress_level.dart';

/// Recorded context for presentation; never used to adjust an AAPS request.
class LowTreatmentObservationContextData {
  final String? activityName;
  final DateTime? activityStartsAt;
  final StressLevel? stressLevel;
  final DateTime? stressObservedAt;

  const LowTreatmentObservationContextData({
    this.activityName,
    this.activityStartsAt,
    this.stressLevel,
    this.stressObservedAt,
  });
}
