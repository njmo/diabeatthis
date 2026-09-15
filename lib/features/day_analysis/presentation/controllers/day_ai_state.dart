import '../../domain/models/day_analysis_draft.dart';

class DayAiState {
  final DayAnalysisDraft? draft;
  final bool isGenerating;
  final bool isSaving;
  final Object? error;
  final Object? saveError;
  const DayAiState({
    this.draft,
    this.isGenerating = false,
    this.isSaving = false,
    this.error,
    this.saveError,
  });
  bool get isBusy => isGenerating || isSaving;
}
