class LowTreatmentReviewDecision {
  final DateTime occurredAt;
  final String? externalId;
  final int? mealId;
  final bool dismissed;
  const LowTreatmentReviewDecision({
    required this.occurredAt,
    this.externalId,
    this.mealId,
    required this.dismissed,
  });
}
