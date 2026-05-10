import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/domain/use_cases/load_activity_log_analysis_use_case.dart';
import '../../data/domain/use_cases/load_activity_log_details_use_case.dart';
import '../models/activity_log_page_state.dart';

part 'activity_log_details_controller.g.dart';

@riverpod
class ActivityLogDetailsControllerNotifier
    extends _$ActivityLogDetailsControllerNotifier {
  @override
  Future<ActivityLogPageState> build(int activityLogId) async {
    final detailsUseCase = ref.read(loadActivityLogDetailsUseCaseProvider);
    final data = await detailsUseCase.call(activityLogId);

    if (data.endedAt == null) {
      return ActivityLogPageState(data: data);
    }

    final analysisUseCase = ref.read(loadActivityLogAnalysisUseCaseProvider);
    try {
      final analysis = await analysisUseCase.call(data);

      return ActivityLogPageState(data: data, analysis: analysis);
    } catch (error) {
      return ActivityLogPageState(data: data, analysisError: error.toString());
    }
  }
}
