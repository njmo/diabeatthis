import '../../domain/models/meal_ai_draft.dart';

class MealAiState {
  final MealAiDraft? draft;
  final bool generating;
  final bool saving;
  final Object? error;
  final Object? saveError;
  const MealAiState({
    this.draft,
    this.generating = false,
    this.saving = false,
    this.error,
    this.saveError,
  });
  bool get busy => generating || saving;
}
