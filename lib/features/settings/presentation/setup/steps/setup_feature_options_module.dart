import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_option_tile.dart';
import '../widgets/setup_notice.dart';
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
            for (final option in feature.options)
              SetupFeatureOptionTile(
                option: option,
                enabled: controller.state.enabledOptions.contains(option.id),
                onChanged: (value) => controller.selectOption(option.id, value),
              ),
            const SizedBox(height: 12),
            SetupNotice(text: context.lang.setupTuneFeatureDemo),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => controller.simulateModule(controller.module!),
              icon: const Icon(Icons.check),
              label: Text(
                controller.moduleReady(controller.module!)
                    ? context.lang.setupChecked
                    : context.lang.setupConfirmFeatureOptions,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
