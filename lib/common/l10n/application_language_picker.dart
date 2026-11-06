import 'package:flutter/material.dart';

import 'application_language.dart';
import 'language.dart';

/// A direct choice of supported languages; system resolution remains automatic
/// until the user makes an explicit selection.
class ApplicationLanguagePicker extends StatelessWidget {
  const ApplicationLanguagePicker({super.key, required this.selected});
  final ApplicationLanguage selected;

  static Future<ApplicationLanguage?> show(
    BuildContext context, {
    required ApplicationLanguage selected,
  }) => showModalBottomSheet<ApplicationLanguage>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Localizations.override(
      context: sheetContext,
      locale: Localizations.localeOf(context),
      child: ApplicationLanguagePicker(selected: selected),
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              context.lang.settingsLanguageFieldLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final language in supportedApplicationLanguages.where(
            (language) => language.locale != null,
          ))
            ListTile(
              title: Text(language.label(context.lang)),
              selected: language.code == selected.code,
              trailing: language.code == selected.code
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.pop(context, language),
            ),
        ],
      ),
    ),
  );
}
