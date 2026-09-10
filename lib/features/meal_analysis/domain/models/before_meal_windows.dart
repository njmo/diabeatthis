/// Observation windows, not insulin action or nutrient absorption durations.
class BeforeMealWindows {
  final Duration glucose;
  final Duration insulin;
  final Duration meals;
  final Duration activities;
  final Duration upcomingActivities;
  const BeforeMealWindows({
    this.glucose = const Duration(minutes: 45),
    this.insulin = const Duration(hours: 6),
    this.meals = const Duration(hours: 24),
    this.activities = const Duration(hours: 24),
    this.upcomingActivities = const Duration(hours: 3),
  });
}
