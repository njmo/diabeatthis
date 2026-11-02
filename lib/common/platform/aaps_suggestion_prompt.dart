import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import '../l10n/language.dart';
import '../widgets/aaps_suggestion_fallback_dialog.dart';
import 'aaps_launcher.dart';

Future<void> openAapsWithSuggestionNotification({
  required BuildContext context,
  required WidgetRef ref,
  required AapsBolusSuggestionNotificationEvent event,
}) async {
  final launcher = ref.read(aapsLauncherProvider);
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
