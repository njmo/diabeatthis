import '../../../../core/domain/model/extended_carb.dart';

/// Scheduled carbohydrate allocation overlapping observation, not absorption.
class ExtendedCarbOverlap {
  final ExtendedCarb treatment;
  final DateTime overlapStart;
  final DateTime overlapEnd;
  final double scheduledGrams;
  final bool startedBeforeMeal;
  const ExtendedCarbOverlap({
    required this.treatment,
    required this.overlapStart,
    required this.overlapEnd,
    required this.scheduledGrams,
    required this.startedBeforeMeal,
  });

  static ExtendedCarbOverlap? between(
    ExtendedCarb treatment,
    DateTime start,
    DateTime end,
  ) {
    if (!treatment.isValid || treatment.duration <= 0 || treatment.carbs <= 0) {
      return null;
    }
    final planEnd = treatment.createdAt.add(
      Duration(milliseconds: treatment.duration),
    );
    final from = treatment.createdAt.isAfter(start)
        ? treatment.createdAt
        : start;
    final until = planEnd.isBefore(end) ? planEnd : end;
    if (!until.isAfter(from)) return null;
    return ExtendedCarbOverlap(
      treatment: treatment,
      overlapStart: from,
      overlapEnd: until,
      scheduledGrams:
          treatment.carbs *
          until.difference(from).inMicroseconds /
          Duration(milliseconds: treatment.duration).inMicroseconds,
      startedBeforeMeal: treatment.createdAt.isBefore(start),
    );
  }
}
