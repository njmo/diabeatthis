import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_account_choice_panel.dart';
import '../widgets/setup_local_profile.dart';
import '../widgets/setup_step_heading.dart';

class SetupStartStep extends StatelessWidget {
  const SetupStartStep({
    super.key,
    required this.controller,
    this.enableProfilePhoto = false,
  });
  final SetupWizardController controller;
  final bool enableProfilePhoto;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      SetupStepHeading(
        title: context.lang.setupWelcomeTitle,
        description: controller.state.signedIn
            ? context.lang.setupWelcomeSignedInDescription
            : context.lang.setupWelcomeDescription,
      ),
      const SizedBox(height: 28),
      if (controller.state.signedIn)
        SetupAccountChoicePanel(controller: controller)
      else
        SetupLocalProfile(
          controller: controller,
          enableProfilePhoto: enableProfilePhoto,
        ),
    ],
  );
}
