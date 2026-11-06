import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_account_choice_panel.dart';
import '../widgets/setup_language_control.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupStartStep extends StatelessWidget {
  const SetupStartStep({super.key, required this.controller});
  final SetupWizardController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (SetupLanguageControl.needsFallbackChoice(controller)) ...[
        SetupLanguageControl(controller: controller),
        const SizedBox(height: 16),
      ],
      SetupNotice(text: context.lang.setupLiveConfigurationNotice),
      const SizedBox(height: 16),
      SetupStepHeading(
        title: context.lang.setupWelcomeTitle,
        description: context.lang.setupWelcomeDescription,
      ),
      const SizedBox(height: 20),
      if (controller.authentication != null)
        SetupAccountChoicePanel(controller: controller),
    ],
  );
}
