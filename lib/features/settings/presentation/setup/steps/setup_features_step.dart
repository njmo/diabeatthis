import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_tile.dart';
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
        title: context.lang.setupFeaturesTitle,
        description: context.lang.setupFeaturesDescription,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (final feature in controller.available)
                SetupFeatureTile(
                  feature: feature,
                  selected:
                      feature.alwaysEnabled ||
                      controller.state.selected.contains(feature.id),
                  onChanged: (value) => controller.select(feature.id, value),
                ),
            ],
          ),
        ),
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
