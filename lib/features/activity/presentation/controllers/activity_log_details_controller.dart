import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/data_sources/stress_events/stress_event_repository.dart';
import '../../../day_analysis/data/providers/day_context_provider.dart';
import '../../data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import '../../data/domain/use_cases/load_activity_log_details_use_case.dart';
import '../../data/domain/use_cases/load_low_treatments_for_activity_log_use_case.dart';
import '../../data/models/activity_log_details_data.dart';
import '../../data/providers/update_completed_activity_times_provider.dart';
import '../models/activity_log_page_state.dart';

part 'activity_log_details_controller.g.dart';

@riverpod
class ActivityLogDetailsControllerNotifier
    extends _$ActivityLogDetailsControllerNotifier {
  @override
  Future<ActivityLogPageState> build(int activityLogId) async {
    ref.watch(stressEventsProvider);
    final detailsUseCase = ref.read(loadActivityLogDetailsUseCaseProvider);
    final data = await detailsUseCase.call(activityLogId);
    final lowTreatments = await ref.read(
      activityLogLowTreatmentsUseCaseProvider(activityLogId).future,
    );

    if (data.endedAt == null) {
      return ActivityLogPageState(data: data, lowTreatments: lowTreatments);
    }

    final analysisUseCase = ref.read(loadActivityLogAnalysisUseCaseProvider);
    try {
      final analysis = await analysisUseCase.call(data);

      return ActivityLogPageState(
        data: data,
        analysis: AsyncData(analysis),
        lowTreatments: lowTreatments,
      );
    } catch (error, stackTrace) {
      return ActivityLogPageState(
        data: data,
        lowTreatments: lowTreatments,
        analysis: AsyncError(error, stackTrace),
      );
    }
  }

  Future<void> updateCompletedTimes({
    required ActivityLogDetailsData original,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    final previousEnd = original.endedAt;
    if (original.id != activityLogId || previousEnd == null) {
      throw ArgumentError('Only this completed activity log can be edited');
    }
    await ref.read(updateCompletedActivityTimesUseCaseProvider)(
      id: activityLogId,
      expectedStart: original.startedAt,
      expectedEnd: previousEnd,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    if (!ref.mounted) return;
    ref.invalidate(dayContextForDateProvider);
    ref.invalidateSelf();
  }

  void selectTimestamp(DateTime timestamp) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedTimestamp: timestamp));
  }
}
