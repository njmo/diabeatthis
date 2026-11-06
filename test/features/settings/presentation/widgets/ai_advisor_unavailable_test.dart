import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_assisted_meal_advisor_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('previous opt-in cannot bypass the temporary production lock', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      aiAssistedMealAdvisorPreferenceKey: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
    );

    await container.read(sharedPrefsProvider.future);
    expect(container.read(aiAssistedMealAdvisorEnabledProvider), isFalse);
    await expectLater(
      container
          .read(aiAssistedMealAdvisorSettingsControllerProvider)
          .save(true),
      throwsStateError,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedMaterialApp(
          home: const Scaffold(body: AiAssistedMealAdvisorSwitch()),
        ),
      ),
    );
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.value, isFalse);
    expect(toggle.onChanged, isNull);
    expect(find.textContaining('Tymczasowo wyłączone'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    expect(container.read(aiAssistedMealAdvisorEnabledProvider), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}
