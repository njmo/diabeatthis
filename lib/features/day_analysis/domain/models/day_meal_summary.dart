class DayMealSummary {
  final int count;
  final int plannedFallbackCount;
  final int missingSnapshotCount;
  final double netCarbs;
  final double protein;
  final double fat;

  const DayMealSummary({
    required this.count,
    required this.plannedFallbackCount,
    required this.missingSnapshotCount,
    required this.netCarbs,
    required this.protein,
    required this.fat,
  });
}
