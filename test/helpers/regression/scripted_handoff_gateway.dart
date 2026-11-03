import 'package:diabeatthis/common/handoff/handoff_gateway.dart';
import 'package:diabeatthis/common/handoff/handoff_instruction.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedHandoffGateway extends Fake implements HandoffGateway {
  @override
  final bool isSupported;
  final ScriptedRead<bool> openings;
  ScriptedHandoffGateway({required this.openings, this.isSupported = true});
  @override
  Future<bool> openInstruction({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) => openings([
    packageName,
    sessionId,
    instruction.steps.map((step) => step.value).toList(),
    instruction.steps.map((step) => step.actionId).toList(),
  ]);
}
