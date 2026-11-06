import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  controller.state.paired
                      ? Icons.check_circle_outline
                      : Icons.qr_code_2,
                  size: 120,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  controller.state.paired
                      ? context.lang.setupPaired
                      : context.lang.setupQrDemo,
                  textAlign: TextAlign.center,
                ),
                if (!controller.state.paired)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: FilledButton.tonal(
                      onPressed: controller.simulatePairing,
                      child: Text(context.lang.setupSimulatePair),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 16),
      SetupNotice(text: context.lang.setupCaregiverProtection),
    ],
  );
}
