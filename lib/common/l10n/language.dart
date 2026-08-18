import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension AppLanguageContext on BuildContext {
  AppLocalizations get lang => AppLocalizations.of(this);
}

AppLocalizations get lang => LanguageStrings.current;

class LanguageStrings {
  const LanguageStrings._();

  static Locale? _selectedLocale;
  static bool _selectedLocaleInitialized = false;

  static void setSelectedLocale(Locale? locale) {
    _selectedLocale = locale;
    _selectedLocaleInitialized = true;
  }

  static AppLocalizations get current {
    final locale = _selectedLocaleInitialized
        ? _selectedLocale ?? PlatformDispatcher.instance.locale
        : const Locale('pl');
    final supportedLocale = _supportedLocaleFor(locale);
    return lookupAppLocalizations(supportedLocale);
  }

  static Locale _supportedLocaleFor(Locale locale) {
    for (final supportedLocale in AppLocalizations.supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }

    return const Locale('pl');
  }
}
