/// Provider-independent, deterministic input for a day analysis.
class DayDmlDocument {
  static const version = 1;
  final String text;
  final Set<String> evidenceIds;
  final Map<String, ({String name, DateTime at})> meals;

  DayDmlDocument({
    required this.text,
    required Set<String> evidenceIds,
    Map<String, ({String name, DateTime at})> meals = const {},
  }) : evidenceIds = Set.unmodifiable(evidenceIds),
       meals = Map.unmodifiable(meals);
}
