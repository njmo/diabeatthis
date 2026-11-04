enum MealPhotoResponseStage { description, resolution }

/// Kept in memory for the diagnostic view and emitted to response diagnostics.
class MealPhotoModelResponse {
  const MealPhotoModelResponse({
    required this.stage,
    required this.text,
    this.truncated = false,
  });
  final MealPhotoResponseStage stage;
  final String text;
  final bool truncated;
}
