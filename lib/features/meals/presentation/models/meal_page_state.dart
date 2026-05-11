import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';

class MealPageState {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final bool showRawTechnicalData;
  final DateTime? selectedTimestamp;
  final DateTime? visibleStart;
  final DateTime? visibleEnd;

  const MealPageState({
    required this.details,
    this.analysis,
    this.analysisError,
    this.showRawTechnicalData = false,
    this.selectedTimestamp,
    this.visibleStart,
    this.visibleEnd,
  });

  MealPageState copyWith({
    MealDetailsData? details,
    MealAnalysisData? analysis,
    String? analysisError,
    bool? showRawTechnicalData,
    DateTime? selectedTimestamp,
    bool clearSelectedTimestamp = false,
    DateTime? visibleStart,
    DateTime? visibleEnd,
    bool clearViewport = false,
  }) {
    return MealPageState(
      details: details ?? this.details,
      analysis: analysis ?? this.analysis,
      analysisError: analysisError ?? this.analysisError,
      showRawTechnicalData: showRawTechnicalData ?? this.showRawTechnicalData,
      selectedTimestamp: clearSelectedTimestamp
          ? null
          : selectedTimestamp ?? this.selectedTimestamp,
      visibleStart: clearViewport ? null : visibleStart ?? this.visibleStart,
      visibleEnd: clearViewport ? null : visibleEnd ?? this.visibleEnd,
    );
  }
}
