import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/widgets/google_account_summary.dart';
import 'package:diabeatthis/common/setup/domain/setup_account_choice.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

void main() {
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
