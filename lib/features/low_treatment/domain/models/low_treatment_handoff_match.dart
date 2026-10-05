class LowTreatmentHandoffMatch {
  final int mealId;
  final DateTime? suggestionAt;
  final DateTime treatAt;
  final String? treatExternalId;

  const LowTreatmentHandoffMatch({
    required this.mealId,
    required this.suggestionAt,
    required this.treatAt,
    required this.treatExternalId,
  });
}
