/// A historical AAPS message, not a new recommendation or proof of treatment.
class RecordedCarbsSuggestion {
  const RecordedCarbsSuggestion({
    required this.grams,
    required this.at,
    required this.withinMinutes,
  });
  final double grams;
  final DateTime at;
  final int? withinMinutes;
}
