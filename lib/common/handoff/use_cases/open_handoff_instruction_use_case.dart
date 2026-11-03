import '../handoff_gateway.dart';
import '../handoff_instruction.dart';

class OpenHandoffInstructionUseCase {
  const OpenHandoffInstructionUseCase(this.gateway);

  final HandoffGateway gateway;

  Future<bool> call({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) {
    if (!gateway.isSupported) return Future.value(false);
    return gateway.openInstruction(
      instruction: instruction,
      packageName: packageName,
      sessionId: sessionId,
    );
  }
}
