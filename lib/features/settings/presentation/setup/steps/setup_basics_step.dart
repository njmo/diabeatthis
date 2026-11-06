import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_account_choice.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/widgets/profile_name_field.dart';
import '../../widgets/application_language_selector.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_account_choice_panel.dart';
import '../widgets/setup_icon_bubble.dart';
import '../widgets/setup_step_heading.dart';

class SetupBasicsStep extends StatelessWidget {
  const SetupBasicsStep({
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
      if (controller.authentication != null)
        SetupAccountChoicePanel(controller: controller),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (controller.authentication == null ||
                  controller.state.accountChoice ==
                      SetupAccountChoice.local) ...[
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
                const SizedBox(height: 16),
              ],
              ApplicationLanguageSelector(
                value: controller.state.language,
                onChanged: (value) {
                  controller.state.language = value;
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

class SetupModeChoice extends StatelessWidget {
  const SetupModeChoice({
    super.key,
    required this.mode,
    required this.selected,
    required this.onSelected,
  });
  final SetupDeviceMode mode;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final patient = mode == SetupDeviceMode.patient;
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SetupIconBubble(
                  icon: patient ? Icons.person_outline : Icons.favorite_outline,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient
                            ? context.lang.setupPatientMode
                            : context.lang.setupCaregiverMode,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        patient
                            ? context.lang.setupPatientModeDescription
                            : context.lang.setupCaregiverModeDescription,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  color: selected ? colors.primary : colors.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
