import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

/// Matches MaterialApp's default resolution across the full system preference list.
Locale resolveSupportedApplicationLocale(List<Locale> preferredLocales) =>
    basicLocaleListResolution(
      preferredLocales,
      AppLocalizations.supportedLocales,
    );
