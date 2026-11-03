import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../handoff/controllers/handoff_controller.dart';
import '../l10n/language.dart';
import '../meal/calculator/meal_handoff_instruction.dart';
import 'external_app_installation_checker.dart';
import 'external_app_instruction_pip.dart';

final aapsSuggestionPipProvider = Provider<AapsSuggestionPip>((ref) {
  return AapsSuggestionPip(enabled: !kIsWeb && Platform.isAndroid);
});

final aapsSuggestionOverlayProvider = Provider<AapsSuggestionPip>((ref) {
  return AapsSuggestionPip(
    // AAPS hides application overlays; use system PiP in the normal flow.
    enabled: false,
    channelName: 'pl.diabeatthis.app/suggestion_overlay',
  );
});

/// Compatibility adapter for meal callers; transport accepts any instruction.
class AapsSuggestionPip extends ExternalAppInstructionPip {
  const AapsSuggestionPip({super.enabled, super.channelName});

  Future<bool> open({
    required AapsBolusSuggestionNotificationEvent event,
    required AppLocalizations strings,
    String? sessionId,
  }) => HandoffController(this).open(
    instruction: MealHandoffInstruction.build(event, strings),
    packageName: ExternalDataApp.aaps.androidPackageName,
    sessionId: sessionId,
  );
}
