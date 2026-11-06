import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_account_choice.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/widgets/profile_name_field.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_account_choice_panel.dart';
import '../widgets/setup_mode_choice.dart';
import '../widgets/setup_step_heading.dart';

class SetupRoleStep extends StatelessWidget {
  const SetupRoleStep({
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
            onSelected: () => controller.setMode(mode),
          ),
        ),
      if (controller.authentication != null &&
          (controller.state.signedIn ||
              controller.state.mode == SetupDeviceMode.caregiver))
        SetupAccountChoicePanel(
          controller: controller,
          allowLocalChoice: false,
        ),
      if (controller.state.mode == SetupDeviceMode.patient &&
          (controller.authentication == null ||
              controller.state.accountChoice == SetupAccountChoice.local))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (enableProfilePhoto)
                  ProfileNameField(
                    initialValue: controller.state.name,
                    label: context.lang.settingsUserNameLabel,
                    onChanged: (value) {
                      controller.state.name = value;
                      controller.changed();
                    },
                  )
                else
                  TextFormField(
                    initialValue: controller.state.name,
                    decoration: InputDecoration(
                      labelText: context.lang.settingsUserNameLabel,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (value) {
                      controller.state.name = value;
                      controller.changed();
                    },
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}
