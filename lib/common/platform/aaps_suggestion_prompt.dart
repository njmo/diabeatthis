import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers/app_event_router_provider.dart';
import '../../core/logger/logger.dart';
import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import '../l10n/language.dart';
import '../meal/calculator/calculator_request_command.dart';
import '../widgets/aaps_suggestion_fallback_dialog.dart';
import 'aaps_launcher.dart';
import 'aaps_suggestion_pip.dart';

Future<void> openAapsWithSuggestionNotification({
  required BuildContext context,
  required WidgetRef ref,
  required AapsBolusSuggestionNotificationEvent event,
}) async {
  final launcher = ref.read(aapsLauncherProvider);
  final overlay = ref.read(aapsSuggestionOverlayProvider);
  if (overlay.isSupported) {
    final opened = await overlay.open(event: event, strings: context.lang);
    if (opened || !context.mounted) return;
  }

  final pip = ref.read(aapsSuggestionPipProvider);
  if (pip.isSupported) {
    final openedAt = clock.now();
    final sessionId =
        '${openedAt.microsecondsSinceEpoch}-${identityHashCode(event)}';
    ref
        .read(appEventRouterProvider)
        .send(
          CalculatorRequestCommand(
            event: event,
            sessionId: sessionId,
            openedAt: openedAt,
          ),
        );
    final opened = await pip.open(
      event: event,
      strings: context.lang,
      sessionId: sessionId,
    );
    if (opened || !context.mounted) return;
  }

  final notificationShown = await showAapsBolusSuggestionNotification(
    ref: ref,
    event: event,
  );
  if (!context.mounted) return;

  if (!notificationShown) {
    final continueToAaps = await showDialog<bool>(
      context: context,
      builder: (_) => AapsSuggestionFallbackDialog(instruction: event.title),
    );
    if (continueToAaps != true || !context.mounted) return;
  }

  final result = await launcher.openAaps();
  if (result == AapsLaunchResult.opened || !context.mounted) return;

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.lang.aapsOpenFailed)));
}

Future<bool> showAapsBolusSuggestionNotification({
  required WidgetRef ref,
  required AapsBolusSuggestionNotificationEvent event,
}) async {
  try {
    await ref.read(notificationsControllerUiProvider).show(event);
    return true;
  } catch (e, st) {
    Log.e(
      'AapsSuggestionPrompt',
      'Could not show AAPS bolus suggestion notification',
      error: e,
      stackTrace: st,
    );
    return false;
  }
}
