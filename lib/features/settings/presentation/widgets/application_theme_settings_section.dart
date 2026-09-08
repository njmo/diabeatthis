import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/application_theme.dart';
import '../../../../common/theme/application_theme_controller.dart';
import '../../../../common/widgets/async_preference_dropdown.dart';
import 'application_theme_mode_selector.dart';
import 'settings_section_card.dart';

class ApplicationThemeSettingsSection extends ConsumerWidget {
  const ApplicationThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(applicationThemeControllerProvider);
    return SettingsSectionCard(
      icon: Icons.palette_outlined,
      title: context.lang.settingsAppearanceTitle,
      subtitle: context.lang.settingsAppearanceSubtitle,
      children: [
        AsyncPreferenceDropdown<ApplicationTheme>(
          value: appearance,
          label: context.lang.settingsAppearanceTitle,
          loadError: context.lang.settingsAppearanceReadError,
          saveError: context.lang.settingsAppearanceSaveError,
          onSave: ref
              .read(applicationThemeControllerProvider.notifier)
              .setTheme,
          items: [
            DropdownMenuItem(
              value: ApplicationTheme.classic,
              child: Text(context.lang.applicationThemeClassic),
            ),
            DropdownMenuItem(
              value: ApplicationTheme.cream,
              child: Text(context.lang.applicationThemeCream),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const ApplicationThemeModeSelector(),
      ],
    );
  }
}
