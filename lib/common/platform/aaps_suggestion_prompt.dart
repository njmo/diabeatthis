import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logger/logger.dart';
import '../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../core/notifications/providers/notifications_controller_provider.dart';
import 'aaps_launcher.dart';

Future<void> openAapsWithSuggestionNotification({
  required BuildContext context,
  required WidgetRef ref,
  required AapsBolusSuggestionNotificationEvent event,
}) async {
  final result = await ref.read(aapsLauncherProvider).openAaps();

  if (result == AapsLaunchResult.opened) {
    await showAapsBolusSuggestionNotification(ref: ref, event: event);
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Nie udało się otworzyć AAPS. Otwórz aplikację ręcznie.'),
    ),
  );
}

Future<void> showAapsBolusSuggestionNotification({
  required WidgetRef ref,
  required AapsBolusSuggestionNotificationEvent event,
}) async {
  try {
    await ref.read(notificationsControllerUiProvider).show(event);
  } catch (e, st) {
    Log.e(
      'AapsSuggestionPrompt',
      'Could not show AAPS bolus suggestion notification',
      error: e,
      stackTrace: st,
    );
  }
}
