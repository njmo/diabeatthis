import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';

class MealPageState {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final DateTime? selectedTimestamp;
  final bool isDownloadingHistory;
  final bool usesLocalHistory;

  /// A successful explicit fetch may legitimately return no AAPS records.
  final bool hasFetchedCloudHistory;

  const MealPageState({
    required this.details,
    this.analysis,
    this.analysisError,
    this.selectedTimestamp,
    this.isDownloadingHistory = false,
    this.usesLocalHistory = false,
    this.hasFetchedCloudHistory = false,
  });

  bool get showHistoryDownload =>
      details.meal.isEaten &&
      usesLocalHistory &&
      (isDownloadingHistory ||
          analysis == null ||
          !analysis!.hasContinuousGlucoseHistory ||
          (!hasFetchedCloudHistory && !analysis!.hasContinuousDeviceHistory));

  MealPageState copyWith({
    MealDetailsData? details,
    MealAnalysisData? analysis,
    String? analysisError,
    DateTime? selectedTimestamp,
    bool clearSelectedTimestamp = false,
    bool? isDownloadingHistory,
  }) {
    return MealPageState(
      details: details ?? this.details,
      usesLocalHistory: usesLocalHistory,
      hasFetchedCloudHistory: hasFetchedCloudHistory,
      isDownloadingHistory: isDownloadingHistory ?? this.isDownloadingHistory,
      analysis: analysis ?? this.analysis,
      analysisError: analysisError ?? this.analysisError,
      selectedTimestamp: clearSelectedTimestamp
          ? null
          : selectedTimestamp ?? this.selectedTimestamp,
    );
  }
}
