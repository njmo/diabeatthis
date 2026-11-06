import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/labeled_divider.dart';
import '../../../../../common/widgets/profile_name_field.dart';
import '../setup_wizard_controller.dart';
import 'setup_account_choice_panel.dart';

class SetupLocalProfile extends StatelessWidget {
  const SetupLocalProfile({
    super.key,
    required this.controller,
    this.enableProfilePhoto = false,
  });
  final SetupWizardController controller;
  final bool enableProfilePhoto;

  void updateName(String value) {
    controller.state.name = value;
    controller.changed();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: enableProfilePhoto
              ? ProfileNameField(
                  initialValue: controller.state.name,
                  label: context.lang.setupEnterUserName,
                  enabled: !controller.state.signingIn,
                  onChanged: updateName,
                )
              : TextFormField(
                  initialValue: controller.state.name,
                  enabled: !controller.state.signingIn,
                  decoration: InputDecoration(
                    labelText: context.lang.setupEnterUserName,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: updateName,
                ),
        ),
      ),
      if (controller.authentication != null) ...[
        LabeledDivider(label: context.lang.setupAlternativeOr),
        SetupAccountChoicePanel(controller: controller, showDescription: false),
      ],
    ],
  );
}
