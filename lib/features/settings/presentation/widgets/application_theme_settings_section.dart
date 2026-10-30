import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'application_theme_mode_selector.dart';
import 'settings_section_card.dart';

class ApplicationThemeSettingsSection extends StatelessWidget {
  const ApplicationThemeSettingsSection({super.key});

  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: Icons.palette_outlined,
    title: context.lang.settingsAppearanceTitle,
    subtitle: context.lang.settingsAppearanceSubtitle,
    children: const [ApplicationThemeModeSelector()],
  );
}
