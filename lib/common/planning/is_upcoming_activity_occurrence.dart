/// Same visible window for local and caregiver upcoming-session lists.
bool isUpcomingActivityOccurrence({
  required String status,
  required int startedAt,
  required DateTime now,
}) =>
    status != 'deleted' &&
    status != 'recorded' &&
    (startedAt > now.millisecondsSinceEpoch ||
        status == 'missed' &&
            startedAt >=
                now.subtract(const Duration(days: 7)).millisecondsSinceEpoch);
