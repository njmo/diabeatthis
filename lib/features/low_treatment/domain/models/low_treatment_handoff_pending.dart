class LowTreatmentHandoffPending {
  final int mealId;
  final DateTime savedAt;
  final double expectedCarbs;
  final DateTime? suggestionAt;
  final DateTime? matchedTreatAt;
  final String? matchedExternalId;

  const LowTreatmentHandoffPending({
    required this.mealId,
    required this.savedAt,
    required this.expectedCarbs,
    required this.suggestionAt,
    required this.matchedTreatAt,
    required this.matchedExternalId,
  });
}
