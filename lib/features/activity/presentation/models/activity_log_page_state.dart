import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_log_details_data.dart';

class ActivityLogPageState {
  final ActivityLogDetailsData data;
  final ActivityLogAnalysisData? analysis;
  final String? analysisError;

  const ActivityLogPageState({
    required this.data,
    this.analysis,
    this.analysisError,
  });
}
