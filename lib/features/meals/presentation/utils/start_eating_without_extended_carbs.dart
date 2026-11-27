import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/l10n/language.dart';
import '../../../../foreground/event/internal/meal_started_without_extended_carbs.dart';

/// Lets the child leave the eCarbs wait when AAPS has no matching eCarbs,
/// for example because they were entered at another time.
Future<void> confirmStartEatingWithoutExtendedCarbs({
  required BuildContext context,
  required WidgetRef ref,
  required int mealId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(lang.mealSkipExtendedCarbsTitle),
      content: Text(lang.mealSkipExtendedCarbsBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: Text(lang.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(lang.mealSkipExtendedCarbsConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final router = ref.read(appEventRouterProvider);
  if (!await FlutterForegroundTask.isRunningService) {
    messenger.showSnackBar(
      SnackBar(content: Text(lang.uiMonitoringUnavailable)),
    );
    return;
  }
  router.send(MealStartedWithoutExtendedCarbs(mealId));
}
