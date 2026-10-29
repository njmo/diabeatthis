/// A scheduled session may deliberately have no end, even when its activity
/// definition has a default duration. Only an absent occurrence uses the default.
int? effectiveActivityDuration({
  required int? activityDuration,
  required bool hasScheduledOccurrence,
  int? occurrenceDuration,
}) => hasScheduledOccurrence ? occurrenceDuration : activityDuration;
