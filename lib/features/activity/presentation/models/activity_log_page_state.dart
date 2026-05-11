import '../../data/models/activity_log_analysis_data.dart';
import '../../data/models/activity_log_details_data.dart';

class ActivityLogPageState {
  final ActivityLogDetailsData data;
  final ActivityLogAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;

  const ActivityLogPageState({
    required this.data,
    this.analysis,
    this.analysisError,
    this.selectedTimestamp,
  });

  ActivityLogPageState copyWith({
    ActivityLogDetailsData? data,
    ActivityLogAnalysisData? analysis,
    String? analysisError,
    DateTime? selectedTimestamp,
    bool clearSelectedTimestamp = false,
  }) {
    return ActivityLogPageState(
      data: data ?? this.data,
      analysis: analysis ?? this.analysis,
      analysisError: analysisError ?? this.analysisError,
      selectedTimestamp: clearSelectedTimestamp
          ? null
          : selectedTimestamp ?? this.selectedTimestamp,
    );
  }
}
