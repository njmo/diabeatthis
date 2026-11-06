import 'dart:ui';

import 'application_language.dart';
import 'resolve_supported_application_locale.dart';

Locale resolveApplicationLocale(
  ApplicationLanguage language, {
  Locale? systemLocale,
  List<Locale>? systemLocales,
}) => resolveSupportedApplicationLocale(
  language.locale != null
      ? [language.locale!]
      : systemLocale != null
      ? [systemLocale]
      : systemLocales ?? PlatformDispatcher.instance.locales,
);
