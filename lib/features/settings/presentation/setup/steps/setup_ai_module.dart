import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/ai_settings_section.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupAiModule extends StatelessWidget {
  const SetupAiModule({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: context.lang.setupAiTitle,
        description: context.lang.setupAiLiveDescription,
      ),
      const SizedBox(height: 16),
      AiSettingsSection(
        submissionController: controller.aiSubmission,
        wizardMode: true,
        onChanged: () => controller.invalidateModule(SetupModule.ai),
        onSaved: () => controller.completeModule(SetupModule.ai),
      ),
      const SizedBox(height: 16),
      SetupNotice(text: context.lang.setupAiOffline, icon: Icons.wifi_off),
    ],
  );
}
