import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_configuration_field.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/setup/domain/validate_setup_module_use_case.dart';
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
          if (widget.controller.state.mode == SetupDeviceMode.caregiver) ...[
            SetupNotice(text: context.lang.caregiverNightscoutReadOnly),
            const SizedBox(height: 12),
          ],
          if (widget.controller.state.mode == SetupDeviceMode.patient &&
              !widget.controller.state.config.usesCloud) ...[
            SetupNotice(text: context.lang.setupNightscoutSessionOnly),
            const SizedBox(height: 12),
          ],
          Form(
            key: formKey,
            autovalidateMode:
                widget.controller.state.attemptedModules.contains(
                  SetupModule.nightscout,
                )
                ? AutovalidateMode.always
                : AutovalidateMode.disabled,
            child: NightscoutConnectionFields(
              urlController: url,
              enabled: !widget.controller.isValidating,
              urlSupporting: SetupConfigurationRequirements(
                controller: widget.controller,
                field: SetupConfigurationField.nightscoutUrl,
              ),
              tokenSupporting: SetupConfigurationRequirements(
                controller: widget.controller,
                field: SetupConfigurationField.nightscoutToken,
              ),
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
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: widget.controller.isValidating
                ? null
                : () => widget.controller.verifyNightscout(),
            child: Text(context.lang.setupNightscoutCheck),
          ),
          if (widget.controller.isCheckingNightscout)
            Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.lang.setupNightscoutChecking)),
              ],
            )
          else if (widget.controller.state.nightscoutVerification
              case final result?)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  result.isSuccess
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: result == SetupNightscoutVerification.previewOnly
                      ? Colors.orange
                      : result.isSuccess
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(switch (result) {
                    SetupNightscoutVerification.readWriteVerified =>
                      context.lang.setupNightscoutReadWriteVerified,
                    SetupNightscoutVerification.readVerified =>
                      context.lang.setupNightscoutReadVerified,
                    SetupNightscoutVerification.tokenRequired =>
                      context.lang.setupNightscoutTokenRequired,
                    SetupNightscoutVerification.invalidToken =>
                      context.lang.setupNightscoutInvalidToken,
                    SetupNightscoutVerification.writeAccessMissing =>
                      context.lang.setupNightscoutWriteAccessMissing,
                    SetupNightscoutVerification.unavailable =>
                      context.lang.setupNightscoutUnavailable,
                    SetupNightscoutVerification.invalidUrl =>
                      context.lang.setupNightscoutInvalidUrl,
                    SetupNightscoutVerification.previewOnly =>
                      context.lang.setupNightscoutPreviewOnly,
                  }),
                ),
              ],
            ),
          if (widget.controller.state.moduleValidationFailed &&
              widget.controller.state.nightscoutVerification == null) ...[
            const SizedBox(height: 12),
            SetupNotice(
              text: context.lang.setupNightscoutValidationFailed,
              icon: Icons.error_outline,
            ),
          ],
        ],
      ),
    ],
  );
}
