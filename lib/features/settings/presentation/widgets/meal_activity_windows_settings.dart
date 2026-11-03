import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_advisor/data/providers/meal_activity_windows_provider.dart';
import 'meal_activity_window_dropdown.dart';

class MealActivityWindowsSettings extends ConsumerWidget {
  const MealActivityWindowsSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(mealActivityWindowsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.lang.mealActivityWindowsTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        MealActivityWindowDropdown(
          value: windows.whenData((w) => w.pastMinutes),
          label: context.lang.mealActivityPastWindow,
          onSave: (minutes) => ref
              .read(mealActivityWindowsControllerProvider)
              .savePastMinutes(minutes),
        ),
        const SizedBox(height: 12),
        MealActivityWindowDropdown(
          value: windows.whenData((w) => w.futureMinutes),
          label: context.lang.mealActivityFutureWindow,
          onSave: (minutes) => ref
              .read(mealActivityWindowsControllerProvider)
              .saveFutureMinutes(minutes),
        ),
      ],
    );
  }
}
