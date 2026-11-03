import 'handoff_instruction.dart';

/// Platform operations available to handoff application logic.
abstract interface class HandoffGateway {
  bool get isSupported;

  Future<bool> openInstruction({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  });

  Future<void> updateRows(String sessionId, List<bool> completed);
  Future<void> dismiss(String sessionId);
}
