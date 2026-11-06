import 'dart:ui';

import 'application_language.dart';
import 'language.dart';

Locale resolveApplicationLocale(
  ApplicationLanguage language, {
  Locale? systemLocale,
}) {
  final preferred =
      language.locale ?? systemLocale ?? PlatformDispatcher.instance.locale;
  return AppLocalizations.supportedLocales.firstWhere(
    (locale) => locale.languageCode == preferred.languageCode,
    orElse: () => const Locale('pl'),
  );
}
