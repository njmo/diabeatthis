import 'package:calculator_handoff/calculator_handoff.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../handoff/controllers/handoff_controller.dart';
import '../handoff/handoff_gateway.dart';
import '../handoff/handoff_instruction.dart';
import '../handoff/handoff_progress.dart';

class ExternalAppInstructionPip implements HandoffGateway {
  const ExternalAppInstructionPip({
    this.enabled = true,
    this.channelName = 'pl.diabeatthis.app/suggestion_pip',
  });

  final bool enabled;
  final String channelName;

  @override
  bool get isSupported =>
      enabled && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> dismiss(String sessionId) async {
    try {
      await MethodChannel(
        channelName,
      ).invokeMethod<void>('dismiss', {'sessionId': sessionId});
    } on MissingPluginException {
      // No native card exists on unsupported platforms.
    } on PlatformException {
      // Manual dismissal remains available if Android already removed the activity.
    }
  }

  /// Can be called by any confirmation source, including the foreground engine.
  /// The native window closes only when every projected requirement is complete.
  Future<void> updateProgress({
    required String sessionId,
    required HandoffProgress progress,
    required Iterable<String> rowActionIds,
  }) => HandoffController(this).publish(
    sessionId: sessionId,
    progress: progress,
    rowActionIds: rowActionIds,
  );

  @override
  Future<void> updateRows(String sessionId, List<bool> completed) =>
      const CalculatorHandoff().update(sessionId, completed);

  @override
  Future<bool> openInstruction({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) async {
    if (!isSupported) return false;
    try {
      return await MethodChannel(channelName).invokeMethod<bool>('openAaps', {
            'packageName': packageName,
            'sessionId': sessionId,
            'title': instruction.title,
            'closeLabel': instruction.closeLabel,
            'labels': [for (final step in instruction.steps) step.label],
            'values': [for (final step in instruction.steps) step.value],
            'prominentRows': [
              for (final step in instruction.steps) step.prominent,
            ],
            'actionRows': [
              for (final step in instruction.steps) step.showCheckbox,
            ],
          }) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
