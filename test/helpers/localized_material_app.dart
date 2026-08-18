import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';

MaterialApp localizedMaterialApp({required Widget home}) {
  return MaterialApp(
    locale: const Locale('pl'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
