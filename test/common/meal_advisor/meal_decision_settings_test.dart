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
  for (final caregiver in [false, true]) {
    testWidgets(
      'shared settings form persists the configured role choice: caregiver=$caregiver',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          aiAssistedMealAdvisorPreferenceKey: true,
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
              home: Scaffold(body: MealDecisionSettings(caregiver: caregiver)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (caregiver) {
          await tester.tap(find.byType(SwitchListTile));
        } else {
          expect(
            container.read(mealDecisionPreferencesProvider).method,
            MealDecisionMethod.ai,
          );
          await tester.tap(find.text('Application'));
        }
        await tester.pumpAndSettle();
        final saved = MealDecisionPreferences.decode(
          prefs.getString(mealDecisionPreferencesKey),
        );
        expect(
          caregiver
              ? saved.caregiverResponsesEnabled
              : saved.method == MealDecisionMethod.ai,
          isFalse,
        );
        expect(saved.method, MealDecisionMethod.app);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
