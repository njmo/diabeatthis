import '../../data/models/meal_analysis_data.dart';
import '../../data/models/meal_details_data.dart';

class MealPageState {
  final MealDetailsData details;
  final MealAnalysisData? analysis;
  final String? analysisError;
  final bool detailedMode;
  final bool showRawTechnicalData;

  const MealPageState({
    required this.details,
    this.analysis,
    this.analysisError,
    this.detailedMode = false,
    this.showRawTechnicalData = false,
  });

  MealPageState copyWith({
    MealDetailsData? details,
    MealAnalysisData? analysis,
    String? analysisError,
    bool? detailedMode,
    bool? showRawTechnicalData,
  }) {
    return MealPageState(
      details: details ?? this.details,
      analysis: analysis ?? this.analysis,
      analysisError: analysisError ?? this.analysisError,
      detailedMode: detailedMode ?? this.detailedMode,
      showRawTechnicalData: showRawTechnicalData ?? this.showRawTechnicalData,
    );
  }
}
