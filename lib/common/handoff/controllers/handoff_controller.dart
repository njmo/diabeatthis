import '../handoff_gateway.dart';
import '../handoff_instruction.dart';
import '../handoff_progress.dart';
import '../use_cases/dismiss_handoff_instruction_use_case.dart';
import '../use_cases/open_handoff_instruction_use_case.dart';
import '../use_cases/publish_handoff_progress_use_case.dart';

/// Coordinates window commands. Feature controllers own persisted domain evidence,
/// so UI and foreground confirmations can publish to the same session.
class HandoffController {
  HandoffController(HandoffGateway gateway)
    : _open = OpenHandoffInstructionUseCase(gateway),
      _publish = PublishHandoffProgressUseCase(gateway),
      _dismiss = DismissHandoffInstructionUseCase(gateway);

  final OpenHandoffInstructionUseCase _open;
  final PublishHandoffProgressUseCase _publish;
  final DismissHandoffInstructionUseCase _dismiss;

  Future<bool> open({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) => _open(
    instruction: instruction,
    packageName: packageName,
    sessionId: sessionId,
  );

  Future<void> publish({
    required String sessionId,
    required HandoffProgress progress,
    required Iterable<String> rowActionIds,
  }) => _publish(
    sessionId: sessionId,
    progress: progress,
    rowActionIds: rowActionIds,
  );

  Future<void> dismiss(String sessionId) => _dismiss(sessionId);
}
