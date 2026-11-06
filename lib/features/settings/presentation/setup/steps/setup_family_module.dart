import 'package:flutter/material.dart';

import '../../../../../common/family/presentation/secure_family_panel.dart';
import '../../../../../common/family/secure_family_repository.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/google_account_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_family_pairing_panel.dart';
import '../widgets/setup_step_heading.dart';

class SetupFamilyModule extends StatelessWidget {
  const SetupFamilyModule({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: controller.state.mode == SetupDeviceMode.patient
            ? context.lang.setupInviteTitle
            : context.lang.setupPairTitle,
        description: controller.authentication == null
            ? context.lang.setupFamilyDescription
            : context.lang.setupFamilyLiveDescription,
      ),
      const SizedBox(height: 16),
      GoogleAccountCard(
        account: controller.state.googleAccount,
        signedIn: controller.state.signedIn,
        busy: controller.state.signingIn,
        failed: controller.state.signInFailed,
        supported: controller.authentication?.isSupported ?? true,
        demo: controller.authentication == null,
        onSignIn: controller.signInGoogle,
        onSignOut: controller.signOutGoogle,
      ),
      if (controller.state.signedIn) ...[
        const SizedBox(height: 16),
        if (controller.familyRepository
            case final SecureFamilyRepository repository)
          SecureFamilyPanel(
            key: ValueKey(controller.state.googleAccount?.uid),
            repository: repository,
            mode: controller.state.mode,
          )
        else
          SetupFamilyPairingPanel(controller: controller),
      ],
    ],
  );
}
