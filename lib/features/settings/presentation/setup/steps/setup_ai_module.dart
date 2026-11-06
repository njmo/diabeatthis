import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_chips.dart';
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
        description: context.lang.setupAiDescription,
      ),
      const SizedBox(height: 16),
      SettingsSectionCard(
        icon: Icons.auto_awesome_outlined,
        title: context.lang.setupAiProvider,
        children: [
          DropdownButtonFormField<String>(
            initialValue: controller.state.aiProvider,
            decoration: InputDecoration(
              labelText: context.lang.setupAiProvider,
            ),
            items: [
              const DropdownMenuItem(
                value: 'firebase',
                child: Text('Firebase AI'),
              ),
              DropdownMenuItem(
                value: 'custom',
                child: Text(context.lang.setupAiOwnProvider),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              controller.state.aiProvider = value;
              controller.state.configured.remove(SetupModule.ai);
              controller.changed();
            },
          ),
          const SizedBox(height: 12),
          Text(context.lang.setupAiModel),
          SetupFeatureChips(
            features: controller.state.selected.where(
              (id) =>
                  id == SetupFeatureId.aiAssistance ||
                  id == SetupFeatureId.mealPhoto,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => controller.simulateModule(SetupModule.ai),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text(
              controller.state.configured.contains(SetupModule.ai)
                  ? context.lang.setupChecked
                  : context.lang.setupSimulateCheck,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      SetupNotice(text: context.lang.setupAiOffline, icon: Icons.wifi_off),
    ],
  );
}
