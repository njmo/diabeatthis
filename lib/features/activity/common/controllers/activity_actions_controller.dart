import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/domain/use_cases/save_started_activity_use_case.dart';
import '../../data/drafts/activity_log_draft.dart';
import '../../data/models/activity_log_summary_data.dart';
import '../../data/providers/activity_provider.dart';
import '../../data/providers/delete_activity_history_entry_provider.dart';
import 'serialized_status_action_controller.dart';

final activityActionsControllerProvider =
    NotifierProvider.autoDispose<ActivityActionsController, AsyncValue<void>>(
      ActivityActionsController.new,
    );

/// Shared by dashboard actions and history, with one in-flight write at a time.
class ActivityActionsController extends SerializedStatusActionController {
  Future<void> saveStarted(ActivityLogDraft draft) => execute(() async {
    await SaveStartedActivityUseCase(
      now: clock.now,
      pendingActivity: () => ref.read(getPendingActivityProvider.future),
      save: (value) async {
        await ref.read(insertActivityLogProvider(value).future);
      },
    )(draft);
    if (ref.mounted) ref.invalidate(getPendingActivityProvider);
  });

  Future<void> end(ActivityLogSummaryData entry) => execute(() async {
    await ref.read(stopActivityProvider(entry).future);
    if (ref.mounted) ref.invalidate(getPendingActivityProvider);
  });

  Future<void> delete(int id) => execute(() async {
    await ref.read(deleteActivityHistoryEntryProvider(id).future);
    if (ref.mounted) ref.invalidate(getPendingActivityProvider);
  });
}
