/// Confirmed progress records, never a planned meal decision or advice.
bool mealHasRecordedBolus({
  required String? currentStatus,
  Iterable<String> history = const [],
}) {
  const confirmedStatuses = {
    'bolused-waiting',
    'bolused-eating',
    'waited-eating',
    'eaten-bolused',
  };
  return confirmedStatuses.contains(currentStatus) ||
      history.any(confirmedStatuses.contains);
}
