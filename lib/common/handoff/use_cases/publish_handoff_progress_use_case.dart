import '../handoff_gateway.dart';
import '../handoff_progress.dart';

class PublishHandoffProgressUseCase {
  const PublishHandoffProgressUseCase(this.gateway);

  final HandoffGateway gateway;

  Future<void> call({
    required String sessionId,
    required HandoffProgress progress,
    required Iterable<String> rowActionIds,
  }) {
    final rows = rowActionIds.toList();
    if (rows.isEmpty || progress.actions.keys.any((id) => !rows.contains(id))) {
      throw ArgumentError(
        'Every required action must be represented in the window',
      );
    }
    if (!gateway.isSupported) return Future.value();
    return gateway.updateRows(sessionId, progress.completedRows(rows));
  }
}
