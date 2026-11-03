enum MealWaitComparison { notApplicable, unavailable, matched, shorter, longer }

class MealApplicationReview {
  const MealApplicationReview({
    required this.proposedWait,
    required this.actualWait,
    required this.consumedCarbs,
    required this.calculatorCarbs,
    required this.calculatorCount,
    required this.manual,
    required this.carbsMatch,
  });
  final Duration? proposedWait;
  final Duration? actualWait;
  final double? consumedCarbs;
  final double? calculatorCarbs;
  final int calculatorCount;
  final bool manual;
  final bool? carbsMatch;

  MealWaitComparison get waitComparison => proposedWait == null
      ? MealWaitComparison.notApplicable
      : actualWait == null
      ? MealWaitComparison.unavailable
      : actualWait == proposedWait
      ? MealWaitComparison.matched
      : actualWait! < proposedWait!
      ? MealWaitComparison.shorter
      : MealWaitComparison.longer;
  Duration? get waitDifference => proposedWait == null || actualWait == null
      ? null
      : (actualWait! - proposedWait!).abs();
}
