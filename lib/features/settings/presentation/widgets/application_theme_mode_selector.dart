import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/application_theme_mode_controller.dart';
import '../../../../common/widgets/async_preference_dropdown.dart';

class ApplicationThemeModeSelector extends ConsumerWidget {
  const ApplicationThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(applicationThemeModeControllerProvider);
    return AsyncPreferenceDropdown<ThemeMode>(
      value: mode,
      label: context.lang.settingsThemeModeLabel,
      loadError: context.lang.settingsAppearanceReadError,
      saveError: context.lang.settingsAppearanceSaveError,
      onSave: ref.read(applicationThemeModeControllerProvider.notifier).setMode,
      items: [
        DropdownMenuItem(
          value: ThemeMode.system,
          child: Text(context.lang.applicationThemeModeSystem),
        ),
        DropdownMenuItem(
          value: ThemeMode.light,
          child: Text(context.lang.applicationThemeModeLight),
        ),
        DropdownMenuItem(
          value: ThemeMode.dark,
          child: Text(context.lang.applicationThemeModeDark),
        ),
      ],
    );
  }
}
