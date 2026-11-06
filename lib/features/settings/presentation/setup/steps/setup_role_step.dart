import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_mode_choice.dart';
import '../widgets/setup_step_heading.dart';

class SetupRoleStep extends StatelessWidget {
  const SetupRoleStep({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: context.lang.setupStartTitle,
        description: context.lang.setupStartDescription,
      ),
      const SizedBox(height: 20),
      for (final mode in SetupDeviceMode.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SetupModeChoice(
            mode: mode,
            selected: controller.state.mode == mode,
            onSelected: controller.canUseMode(mode)
                ? () => controller.setMode(mode)
                : null,
            disabledReason: controller.canUseMode(mode)
                ? null
                : context.lang.setupCaregiverSignInFirst,
          ),
        ),
    ],
  );
}
