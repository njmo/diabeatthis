import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_chips.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupAccessStep extends StatelessWidget {
  const SetupAccessStep({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) {
    final permissions = controller.requirements.entries
        .where((entry) => isSetupSystemRequirement(entry.key))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: context.lang.setupAccessTitle,
          description: context.lang.setupAccessDescription,
        ),
        const SizedBox(height: 16),
        for (final entry in permissions)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: SetupAccessCard(
              requirement: entry.key,
              features: entry.value,
              granted: controller.state.granted.contains(entry.key),
              onGrant: () => controller.grant(entry.key),
            ),
          ),
        if (permissions.isEmpty) Text(context.lang.setupNoRequirements),
        SetupNotice(text: context.lang.setupDemoNotice),
      ],
    );
  }
}

class SetupAccessCard extends StatelessWidget {
  const SetupAccessCard({
    super.key,
    required this.requirement,
    required this.features,
    required this.granted,
    required this.onGrant,
  });
  final SetupRequirement requirement;
  final Set<SetupFeatureId> features;
  final bool granted;
  final VoidCallback onGrant;
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: setupRequirementIcon(requirement),
    title: context.lang.requirementName(requirement),
    children: [
      Row(
        children: [
          Icon(
            granted ? Icons.check_circle_outline : Icons.info_outline,
            size: 17,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              granted
                  ? context.lang.setupAccessGranted
                  : context.lang.setupAccessMissing,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(switch (requirement) {
        SetupRequirement.notifications => context.lang.setupNotificationsWhy,
        SetupRequirement.backgroundExecution => context.lang.setupBackgroundWhy,
        _ => context.lang.setupCameraWhy,
      }, style: Theme.of(context).textTheme.bodySmall),
      if (!granted)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: OutlinedButton(
            onPressed: onGrant,
            child: Text(context.lang.setupSimulateGrant),
          ),
        ),
      SetupFeatureChips(features: features),
    ],
  );
}
