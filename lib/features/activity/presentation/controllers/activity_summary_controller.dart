import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/controllers/serialized_status_action_controller.dart';
import '../../data/providers/save_activity_summary_provider.dart';
import 'activity_log_details_controller.dart';

final activitySummaryControllerProvider =
    NotifierProvider.autoDispose<ActivitySummaryController, AsyncValue<void>>(
      ActivitySummaryController.new,
    );

class ActivitySummaryController extends SerializedStatusActionController {
  Future<void> save({
    required int activityLogId,
    required String? intensity,
    required String notes,
  }) => execute(() async {
    await ref.read(saveActivitySummaryUseCaseProvider)(
      id: activityLogId,
      intensity: intensity,
      notes: notes,
    );
    if (ref.mounted) {
      ref.invalidate(activityLogDetailsControllerProvider(activityLogId));
    }
  });
}
