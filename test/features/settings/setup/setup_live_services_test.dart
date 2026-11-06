import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/family/demo_family_pairing_repository.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/steps/setup_family_module.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_live_services.dart';

SetupWizardState liveServicesDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Demo',
  nightscoutUrl: '',
  nightscoutToken: '',
);
const liveTestAccount = GoogleAccount(
  uid: 'account-a',
  email: 'parent@example.test',
  displayName: 'Test Parent',
);

void main() {
  test(
    'Google identity is restored from auth events and logout clears dummy family membership',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final repository = DemoFamilyPairingRepository();
      addTearDown(repository.dispose);
      final controller = SetupWizardController(
        liveServicesDraft(),
        authentication: auth,
        familyRepository: repository,
      );
      addTearDown(controller.dispose);
      controller.simulateSignIn();
      expect(
        controller.state.signedIn,
        isFalse,
        reason:
            'Production authentication cannot be bypassed by the demo action',
      );
      auth.accounts.add(liveTestAccount);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.googleAccount!.uid, liveTestAccount.uid);
      controller.simulatePairing();
      expect(controller.state.familyMembers, hasLength(1));
      await controller.signOutGoogle();
      expect(controller.state.signedIn, isFalse);
      expect(controller.state.familyMembers, isEmpty);
      expect(repository.members, isEmpty);
    },
  );
  test(
    'a late sign-in result cannot revive an account already signed out by the auth stream',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository()
        ..pending = Completer<GoogleAccount?>();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        liveServicesDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      final signingIn = controller.signInGoogle();
      await controller.signInGoogle();
      expect(auth.calls, 1);
      auth.accounts.add(liveTestAccount);
      auth.accounts.add(null);
      auth.pending!.complete(liveTestAccount);
      await signingIn;
      expect(controller.state.signedIn, isFalse);
      expect(controller.state.signingIn, isFalse);
    },
  );
  test(
    'cancelled login leaves the setup signed out without an error',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        liveServicesDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      await controller.signInGoogle();
      expect(controller.state.signedIn, isFalse);
      expect(controller.state.signInFailed, isFalse);
    },
  );
  test(
    'permissions are only requested by Grant and refusal is not treated as granted',
    () async {
      final gateway = SetupPermissionTestGateway()..allow = false;
      final controller = SetupWizardController(
        liveServicesDraft(),
        permissions: gateway,
      );
      addTearDown(controller.dispose);
      await controller.refreshPermissions();
      expect(gateway.requests, isEmpty);
      await controller.grant(SetupRequirement.notifications);
      expect(gateway.requests, [SetupRequirement.notifications]);
      expect(
        controller.state.granted,
        isNot(contains(SetupRequirement.notifications)),
      );
      expect(
        controller.state.deniedPermissions,
        contains(SetupRequirement.notifications),
      );
      gateway.allow = true;
      await controller.grant(SetupRequirement.notifications);
      expect(
        controller.state.granted,
        contains(SetupRequirement.notifications),
      );
      expect(
        controller.state.deniedPermissions,
        isNot(contains(SetupRequirement.notifications)),
      );
    },
  );
  test(
    'real access step cannot advance until required permissions have been granted',
    () async {
      final gateway = SetupPermissionTestGateway();
      final state = liveServicesDraft()..step = SetupStep.access.index;
      final controller = SetupWizardController(state, permissions: gateway);
      addTearDown(controller.dispose);
      expect(await controller.validateAndNext(), isFalse);
      expect(gateway.requests, isEmpty);
      for (final requirement in [
        SetupRequirement.notifications,
        SetupRequirement.camera,
        SetupRequirement.backgroundExecution,
        SetupRequirement.exactAlarms,
      ]) {
        await controller.grant(requirement);
      }
      expect(await controller.validateAndNext(), isTrue);
      expect(state.currentStep, SetupStep.configuration);
    },
  );
  test(
    'stale permission inspection cannot overwrite a permission granted later',
    () async {
      final gateway = SetupPermissionTestGateway()
        ..pendingCheck = Completer<bool>();
      final controller = SetupWizardController(
        liveServicesDraft(),
        permissions: gateway,
      );
      addTearDown(controller.dispose);
      final checking = controller.refreshPermissions();
      await controller.grant(SetupRequirement.notifications);
      gateway.pendingCheck!.complete(false);
      await checking;
      expect(
        controller.state.granted,
        contains(SetupRequirement.notifications),
      );
    },
  );
  testWidgets(
    'family setup shows Google sign-in and identity while pairing stays simulated',
    (tester) async {
      final auth = SetupGoogleAuthenticationTestRepository()
        ..result = liveTestAccount;
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        liveServicesDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, _) => SetupFamilyModule(controller: controller),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Zaloguj przez Google'), findsOneWidget);
      expect(find.text('Symuluj logowanie Google'), findsNothing);
      await tester.tap(find.text('Zaloguj przez Google'));
      await tester.pumpAndSettle();
      expect(find.text('Test Parent'), findsOneWidget);
      expect(find.text('parent@example.test'), findsOneWidget);
      expect(find.text('Symuluj parowanie'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
