import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupSummaryStep extends StatelessWidget {
  const SetupSummaryStep({
    super.key,
    required this.controller,
    required this.canSavePatient,
  });
  final SetupWizardController controller;
  final bool canSavePatient;

  bool ready(SetupFeature feature) {
    for (final requirement in feature.requirements) {
      if (isSetupSystemRequirement(requirement) &&
          !controller.state.granted.contains(requirement)) {
        return false;
      }
      if (requirement == SetupRequirement.aiConfiguration &&
          !controller.state.configured.contains(SetupModule.ai)) {
        return false;
      }
      if (requirement == SetupRequirement.familyPairing &&
          !controller.state.paired) {
        return false;
      }
    }
    if (feature.requirements.contains(SetupRequirement.dataSource) &&
        controller.state.config.usesCloud &&
        !controller.state.configured.contains(SetupModule.nightscout)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: context.lang.setupSummaryTitle,
        description: context.lang.setupSummaryDescription,
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                controller.state.name,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                controller.state.mode == SetupDeviceMode.patient
                    ? context.lang.setupPatientMode
                    : context.lang.setupCaregiverMode,
              ),
              const Divider(height: 28),
              for (final feature in controller.selected)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(context.lang.featureName(feature.id)),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        ready(feature)
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          ready(feature)
                              ? context.lang.setupReady
                              : context.lang.setupNeedsSetup,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
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
        icon: Icons.storage_outlined,
      ),
      const SizedBox(height: 12),
      SetupNotice(text: context.lang.setupDemoNotice),
      if (canSavePatient)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            context.lang.setupSaveScope,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );
}
