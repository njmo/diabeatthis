import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import '../../data/domain/use_cases/load_activity_log_details_use_case.dart';
import '../../data/domain/use_cases/load_low_treatments_for_activity_log_use_case.dart';
import '../models/activity_log_page_state.dart';

part 'activity_log_details_controller.g.dart';

@riverpod
class ActivityLogDetailsControllerNotifier
    extends _$ActivityLogDetailsControllerNotifier {
  @override
  Future<ActivityLogPageState> build(int activityLogId) async {
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

  void selectTimestamp(DateTime timestamp) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(selectedTimestamp: timestamp));
  }
}
