import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/provider/shared_prefs_provider.dart';
import 'application_language_storage_keys.dart';
import 'language.dart';

part 'application_language.g.dart';

const systemLanguageCode = 'system';

class ApplicationLanguage {
  const ApplicationLanguage({required this.code, required this.locale});

  final String code;
  final Locale? locale;
}

const supportedApplicationLanguages = <ApplicationLanguage>[
  ApplicationLanguage(code: systemLanguageCode, locale: null),
  ApplicationLanguage(code: 'pl', locale: Locale('pl')),
  ApplicationLanguage(code: 'en', locale: Locale('en')),
];

extension ApplicationLanguageLabel on ApplicationLanguage {
  String label(AppLocalizations lang) {
    return switch (code) {
      systemLanguageCode => lang.applicationLanguageSystem,
      'pl' => lang.applicationLanguagePolish,
      'en' => lang.applicationLanguageEnglish,
      _ => code,
    };
  }
}

ApplicationLanguage applicationLanguageByCode(String? code) {
  if (code == null) {
    return supportedApplicationLanguages.firstWhere(
      (language) => language.code == 'pl',
    );
  }

  return supportedApplicationLanguages.firstWhere(
    (language) => language.code == code,
    orElse: () => supportedApplicationLanguages.firstWhere(
      (language) => language.code == 'pl',
    ),
  );
}

Future<ApplicationLanguage> loadApplicationLanguageFromPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  return applicationLanguageByCode(prefs.getString(applicationLanguageCodeKey));
}

void setLanguageStringsFromCode(String? code) {
  final language = applicationLanguageByCode(code);
  LanguageStrings.setSelectedLocale(language.locale);
}

Future<void> initializeLanguageStringsFromPreferences() async {
  final language = await loadApplicationLanguageFromPreferences();
  LanguageStrings.setSelectedLocale(language.locale);
}

@riverpod
class ApplicationLanguageController extends _$ApplicationLanguageController {
  @override
  Future<ApplicationLanguage> build() async {
    final prefs = await ref.watch(sharedPrefsProvider.future);
    final language = applicationLanguageByCode(
      prefs.getString(applicationLanguageCodeKey),
    );
    LanguageStrings.setSelectedLocale(language.locale);
    return language;
  }

  Future<void> setLanguage(ApplicationLanguage language) async {
    final previous = state.maybeWhen(
      data: (language) => language,
      orElse: () => null,
    );
    state = AsyncData(language);
    LanguageStrings.setSelectedLocale(language.locale);

    final prefs = await ref.read(sharedPrefsProvider.future);
    final didSave = await prefs.setString(
      applicationLanguageCodeKey,
      language.code,
    );

    if (!didSave) {
      if (previous != null) {
        state = AsyncData(previous);
        LanguageStrings.setSelectedLocale(previous.locale);
      }
      throw StateError('Could not save application language.');
    }

    ref.invalidate(sharedPrefsProvider);
  }
}
