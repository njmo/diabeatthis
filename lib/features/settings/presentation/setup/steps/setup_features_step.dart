import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/setup/domain/setup_feature_group.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_group_section.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupFeaturesStep extends StatelessWidget {
  const SetupFeaturesStep({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: context.lang.setupCapabilitiesTitle,
        description: context.lang.setupCapabilitiesDescription,
      ),
      const SizedBox(height: 16),
      if (controller.state.mode == SetupDeviceMode.caregiver) ...[
        SetupNotice(text: context.lang.setupCaregiverCapabilitiesNotice),
        const SizedBox(height: 16),
      ],
      for (final group in SetupFeatureGroup.values)
        if (controller.available.any((feature) => feature.group == group))
          SetupFeatureGroupSection(
            group: group,
            features: controller.available
                .where((feature) => feature.group == group)
                .toList(),
            mode: controller.state.mode,
            selected: controller.state.selected,
            unavailable: controller.available
                .where((feature) => !controller.canEnableFeature(feature.id))
                .map((feature) => feature.id)
                .toSet(),
            locked: controller.familyCareLocked
                ? {SetupFeatureId.familyChat, SetupFeatureId.childOverview}
                : const {},
            onChanged: controller.select,
          ),
      const SizedBox(height: 16),
      SetupNotice(
        text: controller.state.mode == SetupDeviceMode.patient
            ? context.lang.setupLocalWorks
            : context.lang.setupCaregiverOffline,
        icon: Icons.offline_bolt_outlined,
      ),
    ],
  );
}
