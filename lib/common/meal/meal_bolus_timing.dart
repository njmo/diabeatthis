const mealBolusLookback = Duration(minutes: 5);

/// Allows a calculator result recorded shortly before the meal status change.
bool isMealBolusRecent({
  required DateTime bolusAt,
  required DateTime referenceTime,
}) {
  return !bolusAt.isBefore(referenceTime.subtract(mealBolusLookback));
}
