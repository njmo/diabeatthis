import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/meal_decision_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('disabling manual decisions resets manual timeout fallback', (
    tester,
  ) async {
    LanguageStrings.setSelectedLocale(const Locale('en'));
    addTearDown(() => LanguageStrings.setSelectedLocale(null));
    SharedPreferences.setMockInitialValues({
      mealDecisionPreferencesKey: const MealDecisionPreferences(
        method: MealDecisionMethod.caregiver,
        timeoutFallback: MealDecisionTimeoutFallback.manual,
      ).encode(),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWith((ref) async => prefs),
        googleAccountProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPrefsProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: MealDecisionSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Allow manual decision change'));
    await tester.tap(find.text('Allow manual decision change'));
    await tester.pumpAndSettle();
    final saved = MealDecisionPreferences.decode(
      prefs.getString(mealDecisionPreferencesKey),
    );
    expect(saved.allowManualDecision, isFalse);
    expect(saved.timeoutFallback, MealDecisionTimeoutFallback.app);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
