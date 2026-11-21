import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/widgets/google_account_summary.dart';
import 'package:diabeatthis/common/setup/domain/setup_account_choice.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_mode_choice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

void main() {
  test('iOS ignores saved patient mode', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    SharedPreferences.setMockInitialValues({
      applicationDeviceModeKey: ApplicationDeviceMode.patient.name,
    });

    expect(await loadApplicationDeviceMode(), ApplicationDeviceMode.caregiver);
    expect(
      deviceModeFromPreferences(await SharedPreferences.getInstance()),
      ApplicationDeviceMode.caregiver,
    );
  });

  testWidgets('iOS setup exposes only the caregiver role', (tester) async {
    final auth = SetupGoogleAuthenticationTestRepository()
      ..result = const GoogleAccount(uid: 'a', displayName: 'Alex Morgan');
    addTearDown(auth.dispose);
    final draft = accountChoiceDraft();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: SetupWizard(
          initialState: draft,
          availability: const DataSourceOptionAvailability.none(),
          authentication: auth,
        ),
      ),
    );
    expect(draft.mode, SetupDeviceMode.caregiver);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Kontynuuj bez logowania'), findsNothing);

    await tester.tap(find.text('Zaloguj przez Google'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();

    expect(draft.currentStep, SetupStep.role);
    expect(find.text('Jestem opiekunem'), findsOneWidget);
    expect(find.byType(SetupModeChoice), findsOneWidget);
    final wizard = tester.state<SetupWizardViewState>(find.byType(SetupWizard));
    wizard.controller.setMode(SetupDeviceMode.patient);
    expect(draft.mode, SetupDeviceMode.caregiver);
  }, variant: const TargetPlatformVariant({TargetPlatform.iOS}));

  for (final mode in SetupDeviceMode.values) {
    testWidgets('Start identity is separate from the $mode role', (
      tester,
    ) async {
      final auth = SetupGoogleAuthenticationTestRepository()
        ..result = const GoogleAccount(uid: 'a', displayName: 'Alex Morgan');
      addTearDown(auth.dispose);
      final draft = accountChoiceDraft()
        ..step = SetupStep.start.index
        ..mode = SetupDeviceMode.patient
        ..accountChoice = SetupAccountChoice.local;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
            authentication: auth,
          ),
        ),
      );
      expect(find.text('Podaj nazwę użytkownika'), findsOneWidget);
      expect(find.text('lub'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Local Alex');
      expect(draft.name, 'Local Alex');
      expect(find.text('Zaloguj przez Google'), findsOneWidget);
      await tester.ensureVisible(find.text('Zaloguj przez Google'));
      await tester.tap(find.text('Zaloguj przez Google'));
      await tester.pumpAndSettle();
      expect(draft.name, 'Alex Morgan');
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      wizard.controller.setMode(mode);
      wizard.controller.goTo(SetupStep.role.index);
      await tester.pumpAndSettle();
      expect(draft.mode, mode);
      expect(draft.currentStep, SetupStep.role);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Zaloguj przez Google'), findsNothing);
      expect(find.byType(GoogleAccountSummary), findsNothing);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(draft.currentStep, SetupStep.features);
      expect(tester.takeException(), isNull);
    });
  }
  for (final explicitlyDisabled in [false, true]) {
    test(
      'Google restores only automatically disabled family sharing: explicit=$explicitlyDisabled',
      () async {
        final auth = SetupGoogleAuthenticationTestRepository();
        addTearDown(auth.dispose);
        final controller = SetupWizardController(
          accountChoiceDraft(),
          authentication: auth,
        );
        addTearDown(controller.dispose);
        await controller.continueWithoutGoogle();
        expect(controller.state.shareData, isFalse);
        if (explicitlyDisabled) {
          controller.select(SetupFeatureId.familyChat, false);
        }
        auth.accounts.add(
          const GoogleAccount(uid: 'a', displayName: 'Alex Morgan'),
        );
        expect(controller.state.shareData, !explicitlyDisabled);
      },
    );
  }
}
