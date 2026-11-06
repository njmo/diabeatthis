import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_family_pairing_panel.dart';
import '../widgets/setup_notice.dart';
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
        description: context.lang.setupFamilyDescription,
      ),
      const SizedBox(height: 16),
      SettingsSectionCard(
        icon: Icons.account_circle_outlined,
        title: context.lang.setupRequirementGoogle,
        children: [
          if (controller.state.signedIn)
            Text(context.lang.setupSignedIn)
          else
            FilledButton.tonal(
              onPressed: controller.simulateSignIn,
              child: Text(context.lang.setupSimulateSignIn),
            ),
        ],
      ),
      if (controller.state.signedIn) ...[
        const SizedBox(height: 16),
        SetupFamilyPairingPanel(controller: controller),
      ],
      const SizedBox(height: 16),
      SetupNotice(text: context.lang.setupCaregiverProtection),
    ],
  );
}
