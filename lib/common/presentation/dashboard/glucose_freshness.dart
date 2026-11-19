const dashboardGlucoseFreshness = Duration(minutes: 10);

bool dashboardGlucoseIsStale(DateTime? measuredAt, DateTime now) {
  if (measuredAt == null || measuredAt.isAfter(now)) return true;
  return now.difference(measuredAt) >= dashboardGlucoseFreshness;
}
