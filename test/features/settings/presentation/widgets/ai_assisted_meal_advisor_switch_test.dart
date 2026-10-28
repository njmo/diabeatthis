import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_assisted_meal_advisor_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('opt-in is visible, defaults off, and persists a user toggle', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
        child: localizedMaterialApp(
          home: const Scaffold(body: AiAssistedMealAdvisorSwitch()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meal Advisor wspomagany AI'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(prefs.getBool(aiAssistedMealAdvisorPreferenceKey), isTrue);
    expect(tester.takeException(), isNull);
  });
}
