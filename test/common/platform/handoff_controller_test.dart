import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/handoff/handoff_gateway.dart';
import 'package:diabeatthis/common/handoff/handoff_instruction.dart';
import 'package:diabeatthis/common/handoff/handoff_progress.dart';
import 'package:diabeatthis/common/handoff/handoff_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'controller publishes foreground confirmations for the opened session',
    () async {
      final gateway = RecordingHandoffGateway();
      final controller = HandoffController(gateway);
      final instruction = HandoffInstruction(
        title: 'Treatment',
        closeLabel: 'Close',
        steps: [
          const HandoffStep(label: 'Carbs', value: '12 g', actionId: 'carbs'),
        ],
      );
      expect(
        await controller.open(
          instruction: instruction,
          packageName: 'aaps',
          sessionId: 'low:7',
        ),
        isTrue,
      );
      await controller.publish(
        sessionId: 'low:7',
        progress: HandoffProgress({'carbs': false}),
        rowActionIds: ['carbs'],
      );
      await controller.publish(
        sessionId: 'low:7',
        progress: HandoffProgress({'carbs': true}),
        rowActionIds: ['carbs'],
      );
      expect(gateway.updates, [
        [false],
        [true],
      ]);
      expect(gateway.sessions, ['low:7', 'low:7']);
      await controller.dismiss('low:7');
      expect(gateway.dismissed, 'low:7');
    },
  );

  test(
    'unrepresented requirements cannot accidentally complete a window',
    () async {
      final gateway = RecordingHandoffGateway();
      final controller = HandoffController(gateway);
      expect(
        () => controller.publish(
          sessionId: 'low:7',
          progress: HandoffProgress({'carbs': true, 'receipt': false}),
          rowActionIds: ['carbs'],
        ),
        throwsArgumentError,
      );
      expect(gateway.updates, isEmpty);
    },
  );

  test('unsupported platform does not open the gateway', () async {
    final gateway = RecordingHandoffGateway()..isSupported = false;
    final instruction = HandoffInstruction(
      title: 'Treatment',
      closeLabel: 'Close',
      steps: [
        const HandoffStep(label: 'Carbs', value: '12 g', actionId: 'carbs'),
      ],
    );
    expect(
      await HandoffController(
        gateway,
      ).open(instruction: instruction, packageName: 'aaps'),
      isFalse,
    );
    expect(gateway.openCount, 0);
  });
}

class RecordingHandoffGateway implements HandoffGateway {
  @override
  bool isSupported = true;
  int openCount = 0;
  final updates = <List<bool>>[];
  final sessions = <String>[];
  String? dismissed;

  @override
  Future<bool> openInstruction({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) async {
    openCount++;
    return true;
  }

  @override
  Future<void> updateRows(String sessionId, List<bool> completed) async {
    sessions.add(sessionId);
    updates.add(completed);
  }

  @override
  Future<void> dismiss(String sessionId) async {
    dismissed = sessionId;
  }
}
