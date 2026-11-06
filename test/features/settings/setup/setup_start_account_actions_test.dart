import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/widgets/google_brand_mark.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_wizard_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

class StartSignOutFailureRepository
    extends SetupGoogleAuthenticationTestRepository {
  @override
  Future<void> signOut() async => throw StateError('Local selection failed');
}

void main() {
  testWidgets(
    'Start has one local action in the footer and skips directly to Role',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository();
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
      expect(find.text('Konto Google'), findsNothing);
      expect(find.text('Kontynuuj bez logowania'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SetupWizardActions),
          matching: find.text('Kontynuuj bez logowania'),
        ),
        findsOneWidget,
      );
      expect(find.byType(GoogleBrandMark), findsOneWidget);
      expect(find.text('Dalej'), findsNothing);
      await tester.tap(find.text('Kontynuuj bez logowania'));
      await tester.pumpAndSettle();
      expect(draft.currentStep, SetupStep.role);
      expect(draft.shareData, isFalse);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Dalej'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Google sign-in shows a compact branded identity and changes the footer to Next',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository()
        ..result = const GoogleAccount(
          uid: 'parent',
          displayName: 'Alex Morgan',
        );
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
      await tester.ensureVisible(find.text('Zaloguj przez Google'));
      await tester.tap(find.text('Zaloguj przez Google'));
      await tester.pumpAndSettle();
      expect(find.text('Zalogowano jako Alex Morgan'), findsOneWidget);
      expect(find.byType(GoogleBrandMark), findsOneWidget);
      expect(find.text('Konto Google'), findsNothing);
      expect(find.text('Kontynuuj bez logowania'), findsNothing);
      expect(find.text('Dalej'), findsOneWidget);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(draft.currentStep, SetupStep.role);
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      wizard.controller.setMode(SetupDeviceMode.caregiver);
      await tester.pumpAndSettle();
      expect(await wizard.controller.validateAndNext(), isTrue);
      expect(draft.currentStep, SetupStep.features);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'failed local-account transition stays on Start and shows the error',
    (tester) async {
      final auth = StartSignOutFailureRepository();
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
      await tester.tap(find.text('Kontynuuj bez logowania'));
      await tester.pumpAndSettle();
      expect(draft.currentStep, SetupStep.start);
      expect(draft.signInFailed, isTrue);
      expect(find.text('Kontynuuj bez logowania'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
