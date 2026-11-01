enum LowTreatmentSuggestionStatus { none, below, covered, excess }

class LowTreatmentSuggestionComparison {
  const LowTreatmentSuggestionComparison({
    required this.carbs,
    required this.suggestedCarbs,
  });

  final num carbs;
  final num suggestedCarbs;

  LowTreatmentSuggestionStatus get status {
    if (suggestedCarbs <= 0) return LowTreatmentSuggestionStatus.none;
    if (carbs < suggestedCarbs) return LowTreatmentSuggestionStatus.below;
    if (carbs >= 2 * suggestedCarbs) return LowTreatmentSuggestionStatus.excess;
    return LowTreatmentSuggestionStatus.covered;
  }

  num get difference => (carbs - suggestedCarbs).abs();
}
