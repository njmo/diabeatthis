/// Corrects a completed occurrence only; its definition and plan stay unchanged.
class UpdateCompletedActivityTimesUseCase {
  final DateTime Function() now;
  final Future<bool> Function({
    required int id,
    required DateTime expectedStart,
    required DateTime expectedEnd,
    required DateTime startedAt,
    required DateTime endedAt,
  })
  updateIfUnchanged;

  const UpdateCompletedActivityTimesUseCase({
    required this.now,
    required this.updateIfUnchanged,
  });

  Future<void> call({
    required int id,
    required DateTime expectedStart,
    required DateTime expectedEnd,
    required DateTime startedAt,
    required DateTime endedAt,
  }) async {
    if (!endedAt.isAfter(startedAt) || endedAt.isAfter(now())) {
      throw ArgumentError(
        'A completed activity must have a positive duration and end in the past',
      );
    }
    final updated = await updateIfUnchanged(
      id: id,
      expectedStart: expectedStart,
      expectedEnd: expectedEnd,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    if (!updated) {
      throw StateError('The activity log was removed, reopened or changed');
    }
  }
}
