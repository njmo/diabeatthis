import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_configuration_field.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/nightscout_connection_fields.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_configuration_requirements.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupNightscoutModule extends StatefulWidget {
  const SetupNightscoutModule({super.key, required this.controller});
  final SetupWizardController controller;
  @override
  State<SetupNightscoutModule> createState() => SetupNightscoutModuleState();
}

class SetupNightscoutModuleState extends State<SetupNightscoutModule> {
  final formKey = GlobalKey<FormState>();
  late final url = TextEditingController(
    text: widget.controller.state.nightscoutUrl,
  );
  late final token = TextEditingController(
    text: widget.controller.state.nightscoutToken,
  );
  @override
  void dispose() {
    url.dispose();
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SetupStepHeading(
        title: context.lang.setupNightscoutTitle,
        description: context.lang.setupNightscoutDescription,
      ),
      const SizedBox(height: 16),
      SettingsSectionCard(
        icon: Icons.cloud_outlined,
        title: 'Nightscout',
        children: [
          SetupConfigurationRequirements(
            controller: widget.controller,
            module: SetupModule.nightscout,
          ),
          if (!widget.controller.state.config.usesCloud) ...[
            SetupNotice(text: context.lang.setupNightscoutSessionOnly),
            const SizedBox(height: 12),
          ],
          Form(
            key: formKey,
            child: NightscoutConnectionFields(
              urlController: url,
              urlLabel: context.lang.setupRequiredFieldLabel(
                context.lang.settingsNightscoutUrlLabel,
              ),
              tokenRequired: widget.controller.requiredConfiguration
                  .containsKey(SetupConfigurationField.nightscoutToken),
              tokenLabel:
                  widget.controller.requiredConfiguration.containsKey(
                    SetupConfigurationField.nightscoutToken,
                  )
                  ? context.lang.setupRequiredFieldLabel(
                      context.lang.settingsNightscoutTokenLabel,
                    )
                  : null,
              tokenRequiredError:
                  context.lang.setupNightscoutWriteTokenRequired,
              tokenController: token,
              onChanged: (_) =>
                  widget.controller.setNightscout(url.text, token.text),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                widget.controller.simulateModule(SetupModule.nightscout);
              }
            },
            icon: const Icon(Icons.cloud_done_outlined),
            label: Text(
              widget.controller.moduleReady(SetupModule.nightscout)
                  ? context.lang.setupChecked
                  : context.lang.setupSimulateCheck,
            ),
          ),
        ],
      ),
    ],
  );
}
