class SaveActivitySummaryUseCase {
  const SaveActivitySummaryUseCase({required this.saveCompleted});

  final Future<bool> Function({
    required int id,
    required String? intensity,
    required String? notes,
  })
  saveCompleted;

  Future<void> call({
    required int id,
    required String? intensity,
    required String notes,
  }) async {
    final trimmed = notes.trim();
    final saved = await saveCompleted(
      id: id,
      intensity: intensity,
      notes: trimmed.isEmpty ? null : trimmed,
    );
    if (!saved) throw StateError('Completed activity no longer exists');
  }
}
