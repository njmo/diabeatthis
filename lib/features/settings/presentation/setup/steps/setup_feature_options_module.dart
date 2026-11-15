import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/scrollable_chip_rail.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_configuration_field_chip.dart';
import '../widgets/setup_monitoring_choice_card.dart';
import '../widgets/setup_step_heading.dart';

class SetupFeatureOptionsModule extends StatelessWidget {
  const SetupFeatureOptionsModule({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) {
    final feature = controller.selected.singleWhere(
      (feature) => feature.configurationModule == controller.module,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: context.lang.featureName(feature.id),
          description: context.lang.setupTuneFeatureDescription,
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          icon: setupFeatureIcon(feature.id),
          title: context.lang.setupFeatureOptions,
          children: [
            for (final option in feature.options) ...[
              SetupMonitoringChoiceCard(
                title: context.lang.setupMonitoringLocalTitle,
                description: context.lang.setupMonitoringLocalDescription,
                icon: Icons.phone_android_outlined,
                selected: !controller.state.enabledOptions.contains(option.id),
                onSelected: () => controller.selectOption(option.id, false),
              ),
              SetupMonitoringChoiceCard(
                title: context.lang.setupMonitoringUploadTitle,
                description: context.lang.setupMonitoringUploadDescription,
                icon: Icons.cloud_upload_outlined,
                selected: controller.state.enabledOptions.contains(option.id),
                onSelected: () => controller.selectOption(option.id, true),
                chips:
                    controller.state.enabledOptions.contains(option.id) &&
                        option.requiredConfiguration.isNotEmpty
                    ? ScrollableChipRail(
                        children: [
                          for (final field in option.requiredConfiguration)
                            SetupConfigurationFieldChip(field: field),
                        ],
                      )
                    : null,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
