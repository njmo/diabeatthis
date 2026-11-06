import 'package:diabeatthis/common/ai/ai_configuration.dart';
import 'package:diabeatthis/common/ai/ai_provider_kind.dart';
import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/location/residence_country_provider.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/steps/setup_ai_module.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/ai_settings_section.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/residence_country_setting.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/regression/setup_ai_settings_controller.dart';

void main() {
  testWidgets(
    'setup uses saved AI provider, explains funded Firebase access and invalidates after edits',
    (tester) async {
      final ai = SetupAiSettingsTestController(
        configuration: const AiConfiguration(
          provider: AiProviderKind.openAi,
          openAiModel: 'saved-model',
        ),
      );
      final controller = SetupWizardController(
        SetupWizardState(
          config: const DataSourceConfig.defaults(),
          language: applicationLanguageByCode('pl'),
          name: 'Demo',
          nightscoutUrl: '',
          nightscoutToken: '',
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [aiSettingsControllerProvider.overrideWith(() => ai)],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) => SetupAiModule(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AiSettingsSection), findsOneWidget);
      final provider = find.byType(DropdownButton<AiProviderKind>);
      expect(
        tester.widget<DropdownButton<AiProviderKind>>(provider).value,
        AiProviderKind.openAi,
      );
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Model AI'))
            .controller!
            .text,
        'saved-model',
      );
      tester.widget<DropdownButton<AiProviderKind>>(provider).onChanged!(
        AiProviderKind.firebase,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('koszty pokrywa autor aplikacji'),
        findsOneWidget,
      );
      expect(find.text('Zapisz ustawienia AI'), findsNothing);
      expect(find.widgetWithText(TextField, 'Model AI'), findsNothing);
      expect(await controller.aiSubmission.submit(), isTrue);
      await tester.pumpAndSettle();
      expect(ai.tests, 1);
      expect(ai.saves, 1);
      expect(controller.moduleReady(SetupModule.ai), isTrue);
      tester.widget<DropdownButton<AiProviderKind>>(provider).onChanged!(
        AiProviderKind.openAi,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Model AI'),
        'changed-model',
      );
      await tester.pump();
      expect(controller.moduleReady(SetupModule.ai), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'country uses the settings card style and reset restores the system region',
    (tester) async {
      SharedPreferences.setMockInitialValues({residenceCountryKey: 'Portugal'});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            deviceCountryLocalesProvider.overrideWithValue([
              const Locale('pl', 'PL'),
            ]),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(body: ResidenceCountrySetting()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SettingsSectionCard), findsOneWidget);
      expect(find.text('Wybrany kraj: Portugal'), findsOneWidget);
      await tester.tap(find.text('Użyj regionu urządzenia'));
      await tester.pumpAndSettle();
      expect(
        find.text('Automatycznie z regionu urządzenia: PL'),
        findsOneWidget,
      );
      expect(prefs.containsKey(residenceCountryKey), isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
