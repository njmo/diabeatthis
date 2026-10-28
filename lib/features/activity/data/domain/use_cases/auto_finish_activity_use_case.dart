/// Uses a guarded persistence callback so a late timer cannot overwrite a manual
/// finish, a deleted log or a log rescheduled while the monitor was waiting.
class AutoFinishActivityUseCase {
  final DateTime Function() now;
  final Future<bool> Function(int id, DateTime startedAt, DateTime endedAt)
  finishIfOpen;

  const AutoFinishActivityUseCase({
    required this.now,
    required this.finishIfOpen,
  });

  Future<bool> call({
    required int activityLogId,
    required DateTime startsAt,
    required int? durationMinutes,
  }) async {
    if (durationMinutes == null || durationMinutes <= 0) return false;
    final endsAt = startsAt.add(Duration(minutes: durationMinutes));
    if (endsAt.isAfter(now())) return false;
    return finishIfOpen(activityLogId, startsAt, endsAt);
  }
}
