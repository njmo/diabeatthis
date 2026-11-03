import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/meal_activity_windows_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/meal_activity_windows_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/regression/controlled_preferences.dart';

void main() {
  for (final succeeds in [true, false]) {
    testWidgets(
      'changing past window persists or restores on failure: $succeeds',
      (tester) async {
        final prefs = ControlledPreferences()..acceptWrites = succeeds;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPrefsProvider.overrideWith((_) async => prefs)],
            child: localizedMaterialApp(
              home: const Scaffold(
                body: SizedBox(
                  width: 320,
                  child: MealActivityWindowsSettings(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final element = tester.element(
          find.byType(MealActivityWindowsSettings),
        );
        final container = ProviderScope.containerOf(element);
        expect(
          (await container.read(
            mealActivityWindowsProvider.future,
          )).pastMinutes,
          120,
        );
        await tester.tap(find.byType(DropdownButtonFormField<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('3 godz.').last);
        await tester.pumpAndSettle();
        final windows = await container.read(
          mealActivityWindowsProvider.future,
        );
        expect(windows.pastMinutes, succeeds ? 180 : 120);
        expect(windows.futureMinutes, 60);
        expect(prefs.writes, [(key: mealActivityPastMinutesKey, value: 180)]);
        if (!succeeds) {
          expect(
            find.text('Nie udało się zapisać okien aktywności.'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
