import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'resolve_supported_application_locale.dart';

export 'generated/app_localizations.dart';

extension AppLanguageContext on BuildContext {
  AppLocalizations get lang => AppLocalizations.of(this);
}

AppLocalizations get lang => LanguageStrings.current;

class LanguageStrings {
  const LanguageStrings._();

  static Locale? _selectedLocale;

  static void setSelectedLocale(Locale? locale) {
    _selectedLocale = locale;
  }

  static AppLocalizations get current {
    final supportedLocale = resolveSupportedApplicationLocale(
      _selectedLocale == null
          ? PlatformDispatcher.instance.locales
          : [_selectedLocale!],
    );
    return lookupAppLocalizations(supportedLocale);
  }
}
