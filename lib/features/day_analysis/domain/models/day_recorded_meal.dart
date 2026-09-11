class DayRecordedMeal {
  final bool requiresCompletion;
  final int id;
  final String name;
  final DateTime eatenAt;

  const DayRecordedMeal({
    this.requiresCompletion = false,
    required this.id,
    required this.name,
    required this.eatenAt,
  });
}
