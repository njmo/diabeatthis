import '../../models/activity_log_summary_data.dart';

class EndActivityEntryUseCase {
  const EndActivityEntryUseCase({
    required this.now,
    required this.finishIfOpen,
    required this.cancelIfUnchanged,
  });
  final DateTime Function() now;
  final Future<bool> Function(int id, DateTime start, DateTime end)
  finishIfOpen;
  final Future<bool> Function(int id, DateTime start) cancelIfUnchanged;

  Future<void> call(ActivityLogSummaryData entry) async {
    if (entry.endedAt != null) throw StateError('Activity is already finished');
    final current = now();
    final changed = entry.startedAt.isAfter(current)
        ? await cancelIfUnchanged(entry.id, entry.startedAt)
        : await finishIfOpen(entry.id, entry.startedAt, current);
    if (!changed) throw StateError('The activity was removed or changed');
  }
}
