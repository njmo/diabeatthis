import 'package:flutter/material.dart';

import '../../../../../common/l10n/application_language.dart';
import '../../../../../common/l10n/has_supported_system_language.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/l10n/resolve_application_locale.dart';
import '../../widgets/application_language_selector.dart';
import '../setup_wizard_controller.dart';

class SetupLanguageControl extends StatelessWidget {
  const SetupLanguageControl({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final SetupWizardController controller;
  final bool compact;

  static bool needsFallbackChoice(SetupWizardController controller) =>
      controller.state.language.locale == null &&
      !hasSupportedSystemLanguage(
        WidgetsBinding.instance.platformDispatcher.locales,
      );

  void selectLanguage(ApplicationLanguage language) {
    controller.state.language = language;
    controller.changed();
  }

  @override
  Widget build(BuildContext context) {
    if (!compact) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ApplicationLanguageSelector(
            value: controller.state.language,
            onChanged: selectLanguage,
          ),
        ),
      );
    }
    final locale = resolveApplicationLocale(
      controller.state.language,
      systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
    );
    return TextButton.icon(
      icon: const Icon(Icons.language),
      label: Text(
        applicationLanguageByCode(locale.languageCode).label(context.lang),
      ),
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => Localizations.override(
          context: sheetContext,
          locale: Localizations.localeOf(context),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ApplicationLanguageSelector(
                value: controller.state.language,
                onChanged: (language) {
                  selectLanguage(language);
                  Navigator.pop(sheetContext);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
