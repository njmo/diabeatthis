import '../../models/activity_log_details_data.dart';
import 'save_activity_summary_use_case.dart';
import 'update_completed_activity_times_use_case.dart';

class UpdateCompletedActivityEntryUseCase {
  const UpdateCompletedActivityEntryUseCase({
    required this.updateTimes,
    required this.saveSummary,
    required this.transaction,
  });
  final UpdateCompletedActivityTimesUseCase updateTimes;
  final SaveActivitySummaryUseCase saveSummary;
  final Future<void> Function(Future<void> Function() action) transaction;

  Future<void> call({
    required int id,
    required ActivityLogDetailsData original,
    required DateTime startedAt,
    required DateTime endedAt,
    required String? intensity,
    required String notes,
  }) async {
    final previousEnd = original.endedAt;
    if (original.id != id || previousEnd == null) {
      throw ArgumentError('Only this completed activity log can be edited');
    }
    await transaction(() async {
      await updateTimes(
        id: id,
        expectedStart: original.startedAt,
        expectedEnd: previousEnd,
        startedAt: startedAt,
        endedAt: endedAt,
      );
      await saveSummary(id: id, intensity: intensity, notes: notes);
    });
  }
}
