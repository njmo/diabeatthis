import '../handoff_gateway.dart';

class DismissHandoffInstructionUseCase {
  const DismissHandoffInstructionUseCase(this.gateway);

  final HandoffGateway gateway;

  Future<void> call(String sessionId) => gateway.dismiss(sessionId);
}
