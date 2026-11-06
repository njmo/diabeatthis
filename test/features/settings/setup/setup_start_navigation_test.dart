import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/setup/domain/setup_account_choice.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/setup_live_services.dart';
import 'setup_account_choice_test.dart' show accountChoiceDraft;

void main() {
  test(
    'returning from caregiver to local Start disables patient sharing only',
    () async {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final controller = SetupWizardController(
        accountChoiceDraft(),
        authentication: auth,
      );
      addTearDown(controller.dispose);
      auth.accounts.add(const GoogleAccount(uid: 'a', displayName: 'Parent'));
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.mode, SetupDeviceMode.caregiver);
      await controller.continueWithoutGoogle();
      expect(controller.state.mode, SetupDeviceMode.patient);
      expect(
        controller.state.selectedByMode[SetupDeviceMode.caregiver],
        contains(SetupFeatureId.familyChat),
      );
      expect(
        controller.state.selectedByMode[SetupDeviceMode.patient],
        isNot(contains(SetupFeatureId.familyChat)),
      );
      expect(await controller.validateAndNext(), isTrue);
      expect(controller.state.currentStep, SetupStep.role);
      expect(controller.canUseMode(SetupDeviceMode.caregiver), isFalse);
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.mode, SetupDeviceMode.patient);
      expect(controller.state.accountChoice, SetupAccountChoice.local);
      expect(controller.state.shareData, isFalse);
      expect(await controller.validateAndNext(), isTrue);
    },
  );
  test('navigation waits for a pending Google account transition', () async {
    final auth = SetupGoogleAuthenticationTestRepository()
      ..pending = Completer<GoogleAccount?>();
    addTearDown(auth.dispose);
    final controller = SetupWizardController(
      accountChoiceDraft(),
      authentication: auth,
    );
    addTearDown(controller.dispose);
    await controller.continueWithoutGoogle();
    final login = controller.signInGoogle();
    expect(await controller.validateAndNext(), isFalse);
    expect(controller.next(), isFalse);
    expect(controller.state.currentStep, SetupStep.start);
    auth.pending!.complete(null);
    await login;
    expect(await controller.validateAndNext(), isTrue);
    expect(controller.state.currentStep, SetupStep.role);
  });
}
