import 'package:flutter/material.dart';

import '../../../../../common/l10n/application_language.dart';
import '../../../../../common/l10n/application_language_picker.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/l10n/resolve_application_locale.dart';
import '../setup_wizard_controller.dart';

class SetupLanguageControl extends StatelessWidget {
  const SetupLanguageControl({super.key, required this.controller});
  final SetupWizardController controller;

  @override
  Widget build(BuildContext context) {
    final locale = resolveApplicationLocale(
      controller.state.language,
      systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
    );
    final selected = applicationLanguageByCode(locale.languageCode);
    return TextButton.icon(
      icon: const Icon(Icons.language),
      label: Text(selected.label(context.lang)),
      onPressed: () async {
        final language = await ApplicationLanguagePicker.show(
          context,
          selected: selected,
        );
        if (!context.mounted || controller.disposed || language == null) return;
        controller.state.language = language;
        controller.changed();
      },
    );
  }
}
