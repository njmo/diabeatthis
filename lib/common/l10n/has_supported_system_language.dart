import 'dart:ui';

import 'application_language.dart';

/// Checks the entire device preference list before falling back to English.
bool hasSupportedSystemLanguage(List<Locale> locales) => locales.any(
  (locale) => supportedApplicationLanguages.any(
    (language) => language.locale?.languageCode == locale.languageCode,
  ),
);
