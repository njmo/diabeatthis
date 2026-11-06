import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/widgets/profile_name_field.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/application/apply_caregiver_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/presentation/screens/initial_configuration_page.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/scripted_caregiver_configuration_use_case.dart';
import '../../../helpers/regression/scripted_initial_configuration_use_case.dart';
import '../../../helpers/regression/scripted_read.dart';
import '../../../helpers/regression/setup_live_services.dart';

void main() {
  const local = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );

  testWidgets(
    'initial wizard preserves profile photo entry and delegates the patient draft to the existing save use case',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writes = ScriptedRead<void>('patient wizard save', [
        (
          arguments: [local, '', '', 'New child', 'en'],
          respond: () =>
              throw StateError('Keep the wizard open to verify recovery'),
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAuthenticationRepositoryProvider.overrideWithValue(auth),
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            dataSourceConfigProvider.overrideWith((ref) async => local),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => const DataSourceOptionAvailability(
                aapsInstalled: true,
                xdripInstalled: false,
              ),
            ),
            applyInitialConfigurationUseCaseProvider.overrideWithValue(
              ScriptedInitialConfigurationUseCase(writes),
            ),
          ],
          child: localizedMaterialApp(home: const InitialConfigurationPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNameField), findsOneWidget);
      await tester.ensureVisible(find.text('Continue without signing in'));
      await tester.tap(find.text('Continue without signing in'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNameField), findsNothing);
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      wizard.controller.state.name = ' New child ';
      wizard.controller.state.language = applicationLanguageByCode('en');
      wizard.controller.goTo(SetupStep.summary.index);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save patient configuration'));
      await tester.pumpAndSettle();
      writes.verifyComplete();
      expect(
        find.text(
          lookupAppLocalizations(
            applicationLanguageByCode('en').locale!,
          ).settingsInitialSaveError,
        ),
        findsOneWidget,
      );
      expect(find.byType(SetupWizard), findsOneWidget);
      expect(find.text('Save patient configuration'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'caregiver completion delegates its own save without patient writes',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final writes = ScriptedRead<void>(
        'patient save must not run for caregiver',
        [],
      );
      final caregiverWrites = ScriptedRead<void>('caregiver save', [
        (
          arguments: ['https://example.test', '', 'Test Parent', 'en'],
          respond: () => throw StateError('Keep wizard open'),
        ),
      ]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applyCaregiverConfigurationProvider.overrideWith(
              (ref) =>
                  ScriptedCaregiverConfigurationUseCase(ref, caregiverWrites),
            ),
            googleAuthenticationRepositoryProvider.overrideWithValue(auth),
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            dataSourceConfigProvider.overrideWith((ref) async => local),
            dataSourceOptionAvailabilityProvider.overrideWith(
              (ref) async => const DataSourceOptionAvailability(
                aapsInstalled: true,
                xdripInstalled: false,
              ),
            ),
            applyInitialConfigurationUseCaseProvider.overrideWithValue(
              ScriptedInitialConfigurationUseCase(writes),
            ),
          ],
          child: localizedMaterialApp(home: const InitialConfigurationPage()),
        ),
      );
      await tester.pumpAndSettle();
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      auth.result = const GoogleAccount(
        uid: 'parent',
        displayName: 'Test Parent',
      );
      await wizard.controller.signInGoogle();
      wizard.controller.setMode(SetupDeviceMode.caregiver);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileNameField), findsNothing);
      expect(wizard.controller.state.name, 'Test Parent');
      wizard.controller.state.language = applicationLanguageByCode('en');
      wizard.controller.state.nightscoutUrl = 'https://example.test';
      wizard.controller.state.configured.add(SetupModule.nightscout);
      wizard.controller.goTo(SetupStep.summary.index);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save caregiver configuration'));
      await tester.pumpAndSettle();
      caregiverWrites.verifyComplete();
      expect(wizard.controller.state.mode, SetupDeviceMode.caregiver);
      expect(find.text('Save caregiver configuration'), findsOneWidget);
      expect(prefs.getKeys(), isEmpty);
      writes.verifyComplete();
      expect(tester.takeException(), isNull);
    },
  );
}
