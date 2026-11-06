import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/google_account_card.dart';
import '../setup_wizard_controller.dart';

class SetupAccountChoicePanel extends StatelessWidget {
  const SetupAccountChoicePanel({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GoogleAccountCard(
          account: controller.state.googleAccount,
          signedIn: controller.state.signedIn,
          busy: controller.state.signingIn,
          failed: controller.state.signInFailed,
          supported: controller.authentication?.isSupported ?? true,
          onSignIn: controller.signInGoogle,
          onSignOut: controller.signOutGoogle,
        ),
        const SizedBox(height: 8),
        if (!controller.state.signedIn &&
            controller.state.mode == SetupDeviceMode.patient)
          OutlinedButton.icon(
            onPressed: controller.state.signingIn
                ? null
                : controller.continueWithoutGoogle,
            icon: const Icon(Icons.person_outline),
            label: Text(context.lang.setupContinueWithoutGoogle),
          ),
        Text(
          controller.state.mode == SetupDeviceMode.caregiver
              ? context.lang.setupCaregiverGoogleRequired
              : context.lang.setupLocalAccountDescription,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
