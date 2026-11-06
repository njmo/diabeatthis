import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_account_choice.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/widgets/profile_avatar.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';

SetupWizardState accountChoiceDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Local name',
  nightscoutUrl: '',
  nightscoutToken: '',
);

void main() {
  test(
    'local choice disables sharing without a Google session and caregiver cannot choose local',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        accountChoiceDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      expect(await controller.validateAndNext(), isFalse);
      await controller.continueWithoutGoogle();
      expect(controller.state.accountChoice, SetupAccountChoice.local);
      expect(controller.state.shareData, isFalse);
      expect(await controller.validateAndNext(), isTrue);
      controller.setMode(SetupDeviceMode.caregiver);
      controller.goTo(SetupStep.start.index);
      await controller.continueWithoutGoogle();
      expect(controller.state.accountChoice, SetupAccountChoice.undecided);
      expect(await controller.validateAndNext(), isFalse);
    },
  );
  test(
    'Google imports the full name and avatar without discarding the local fallback',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        accountChoiceDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      auth.accounts.add(
        const GoogleAccount(
          uid: 'a',
          displayName: 'Alex Morgan',
          email: 'alex@example.test',
          photoUrl: 'https://example.test/avatar.png',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.name, 'Alex Morgan');
      expect(
        controller.state.googleAccount!.photoUrl,
        'https://example.test/avatar.png',
      );
      controller.simulatePairing();
      final members = controller.state.familyMembers;
      auth.accounts.add(
        const GoogleAccount(
          uid: 'a',
          displayName: 'Alex Morgan Smith',
          email: 'alex@example.test',
          photoUrl: 'https://example.test/new.png',
        ),
      );
      expect(controller.state.name, 'Alex Morgan Smith');
      expect(controller.state.familyMembers, members);
      await controller.signOutGoogle();
      expect(controller.state.name, 'Local name');
    },
  );
  testWidgets(
    'start offers Google or local mode and does not ask for a name when signed in',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository()
        ..result = const GoogleAccount(
          uid: 'a',
          displayName: 'Alex Morgan',
          email: 'alex@example.test',
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
      expect(find.text('Zaloguj przez Google'), findsOneWidget);
      expect(find.text('Kontynuuj bez logowania'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(find.text('Zaloguj przez Google'));
      await tester.tap(find.text('Zaloguj przez Google'));
      await tester.pumpAndSettle();
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.byType(ProfileAvatar), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(draft.name, 'Alex Morgan');
      await tester.ensureVisible(find.text('Wyloguj'));
      await tester.tap(find.text('Wyloguj'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kontynuuj bez logowania'));
      await tester.tap(find.text('Kontynuuj bez logowania'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsOneWidget);
      expect(draft.accountChoice, SetupAccountChoice.local);
      expect(tester.takeException(), isNull);
    },
  );
}
