import 'package:diabeatthis/common/handoff/handoff_instruction.dart';
import 'package:diabeatthis/common/handoff/handoff_progress.dart';
import 'package:diabeatthis/common/handoff/handoff_step.dart';
import 'package:diabeatthis/common/platform/external_app_instruction_pip.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'completion requires every action and leaves unknown actions pending',
    () {
      final progress = HandoffProgress({'carbs': true, 'receipt': false});
      expect(progress.isComplete, isFalse);
      expect(
        progress.completedRows(['receipt', 'carbs', 'receipt', 'unknown']),
        [false, true, false, false],
      );
      expect(HandoffProgress({'carbs': true}).isComplete, isTrue);
      expect(HandoffProgress({}).isComplete, isFalse);
    },
  );

  test(
    'independent confirmation sources project all requirements to one session',
    () async {
      const channel = MethodChannel('pl.diabeatthis.app/calculator_handoff');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final updates = <List<bool>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'update');
        expect(call.arguments['sessionId'], 'task:42');
        updates.add((call.arguments['completed'] as List).cast<bool>());
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      for (final actions in [
        {'carbs': true, 'receipt': false},
        {'carbs': true, 'receipt': true},
        {'carbs': false, 'receipt': true},
      ]) {
        await const ExternalAppInstructionPip().updateProgress(
          sessionId: 'task:42',
          progress: HandoffProgress(actions),
          rowActionIds: ['carbs', 'receipt', 'receipt'],
        );
      }
      expect(updates, [
        [true, false, false],
        [true, true, true],
        [false, true, true],
      ]);
    },
  );

  test('instruction protects the native row limit', () {
    expect(
      () => HandoffInstruction(title: 'Task', closeLabel: 'Close', steps: []),
      throwsArgumentError,
    );
    expect(
      () => HandoffInstruction(
        title: 'Task',
        closeLabel: 'Close',
        steps: List.generate(
          4,
          (i) => HandoffStep(label: '$i', value: '$i', actionId: '$i'),
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'opens a carbohydrate instruction without a meal or bolus event',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      const channel = MethodChannel('pl.diabeatthis.app/suggestion_pip');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() {
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['sessionId'], 'low:42');
        expect(call.arguments['labels'], ['Carbohydrates']);
        expect(call.arguments['values'], ['12 g']);
        return true;
      });
      expect(
        await const ExternalAppInstructionPip().openInstruction(
          instruction: HandoffInstruction(
            title: 'Low treatment',
            closeLabel: 'Close',
            steps: [
              const HandoffStep(
                label: 'Carbohydrates',
                value: '12 g',
                actionId: 'carbs',
              ),
            ],
          ),
          packageName: 'info.nightscout.androidaps',
          sessionId: 'low:42',
        ),
        isTrue,
      );
    },
  );
}
