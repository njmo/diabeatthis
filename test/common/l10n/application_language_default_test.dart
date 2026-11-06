import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/l10n/resolve_application_locale.dart';
import 'package:diabeatthis/common/l10n/resolve_supported_application_locale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('system is selected when no supported preference is stored', () {
    expect(applicationLanguageByCode(null).code, 'system');
    expect(applicationLanguageByCode('unknown').code, 'system');
  });
  test('explicit Polish and English selections remain unchanged', () {
    expect(applicationLanguageByCode('pl').locale, const Locale('pl'));
    expect(applicationLanguageByCode('en').locale, const Locale('en'));
    expect(applicationLanguageByCode('system').locale, isNull);
  });
  for (final systemLocales in [
    ['pl'],
    ['en'],
    ['de'],
    ['de', 'pl'],
    ['de', 'en'],
    ['de', 'fr'],
  ]) {
    testWidgets(
      'system locales $systemLocales resolves consistently in the app and shared resolver',
      (tester) async {
        tester.binding.platformDispatcher.localesTestValue = systemLocales
            .map(Locale.new)
            .toList();
        addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
        addTearDown(() => setLanguageStringsFromCode('pl'));
        final language = applicationLanguageByCode(null);
        final expected = systemLocales.contains('pl') ? 'pl' : 'en';
        setLanguageStringsFromCode(language.code);
        await tester.pumpWidget(
          MaterialApp(
            locale: language.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) =>
                  Text(Localizations.localeOf(context).languageCode),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(resolveApplicationLocale(language, systemLocales: systemLocales.map(Locale.new).toList()).languageCode, expected);
        expect(lookupAppLocalizations(resolveSupportedApplicationLocale(systemLocales.map(Locale.new).toList())).localeName, expected);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
