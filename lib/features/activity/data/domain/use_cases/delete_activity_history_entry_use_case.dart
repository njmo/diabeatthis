/// Removes a single occurrence. Definitions and other sessions are retained.
class DeleteActivityHistoryEntryUseCase {
  const DeleteActivityHistoryEntryUseCase({required this.deleteById});
  final Future<void> Function(int id) deleteById;

  Future<void> call(int id) async {
    if (id <= 0) throw ArgumentError.value(id, 'id');
    await deleteById(id);
  }
}
