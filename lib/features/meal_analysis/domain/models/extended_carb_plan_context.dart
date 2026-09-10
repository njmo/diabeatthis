import '../../../../core/domain/model/extended_carb.dart';

/// Progress through a recorded eCarbs schedule, not estimated absorption or COB.
class ExtendedCarbPlanContext {
  final ExtendedCarb treatment;
  final DateTime endsAt;
  final double scheduledBeforeCutoffGrams;
  final double scheduledAfterCutoffGrams;
  const ExtendedCarbPlanContext({
    required this.treatment,
    required this.endsAt,
    required this.scheduledBeforeCutoffGrams,
    required this.scheduledAfterCutoffGrams,
  });

  static ExtendedCarbPlanContext? at(ExtendedCarb treatment, DateTime cutoff) {
    if (!treatment.isValid ||
        treatment.carbs <= 0 ||
        treatment.duration <= 0 ||
        treatment.createdAt.isAfter(cutoff)) {
      return null;
    }
    final end = treatment.createdAt.add(
      Duration(milliseconds: treatment.duration),
    );
    if (!end.isAfter(cutoff)) return null;
    final elapsed = cutoff.difference(treatment.createdAt).inMilliseconds;
    final before =
        treatment.carbs * (elapsed / treatment.duration).clamp(0.0, 1.0);
    return ExtendedCarbPlanContext(
      treatment: treatment,
      endsAt: end,
      scheduledBeforeCutoffGrams: before,
      scheduledAfterCutoffGrams: treatment.carbs - before,
    );
  }
}
