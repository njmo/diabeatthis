import '../../drafts/activity_log_draft.dart';
import '../../models/activity_log_summary_data.dart';

/// Records a currently started session independently of any target's start.
class SaveStartedActivityUseCase {
  const SaveStartedActivityUseCase({
    required this.now,
    required this.pendingActivity,
    required this.save,
  });
  final DateTime Function() now;
  final Future<ActivityLogSummaryData?> Function() pendingActivity;
  final Future<void> Function(ActivityLogDraft draft) save;

  Future<void> call(ActivityLogDraft draft) async {
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    if (draft.startedAt.isAfter(current) ||
        draft.startedAt.isBefore(today) ||
        draft.endedAt != null) {
      throw ArgumentError(
        'A started activity must begin today and not in the future',
      );
    }
    final pending = await pendingActivity();
    if (pending != null &&
        pending.endedAt == null &&
        !pending.startedAt.isAfter(current)) {
      throw StateError('An activity is already running');
    }
    await save(draft);
  }
}
