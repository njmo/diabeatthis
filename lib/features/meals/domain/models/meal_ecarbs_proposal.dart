enum MealEcarbsProposalKind { extendedCarbs, extraBolus, unknown }

class MealEcarbsProposal {
  const MealEcarbsProposal({
    required this.hasDecision,
    required this.kind,
    required this.grams,
    required this.delayMinutes,
    required this.durationMinutes,
  });
  final bool hasDecision;
  final MealEcarbsProposalKind kind;
  final int? grams;
  final int? delayMinutes;
  final int? durationMinutes;
  bool get hasSchedule =>
      kind == MealEcarbsProposalKind.extendedCarbs &&
      grams != null &&
      delayMinutes != null &&
      durationMinutes != null;
}
