import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../../../../common/widgets/show_localized_dialog.dart';
import '../../../../../core/data_sources/config/data_source_option_availability.dart';
import '../../widgets/data_source_config_controls.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_feature_chips.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupDataStep extends StatelessWidget {
  const SetupDataStep({
    super.key,
    required this.controller,
    required this.availability,
  });
  final SetupWizardController controller;
  final DataSourceOptionAvailability availability;
  @override
  Widget build(BuildContext context) {
    final caregiver = controller.state.mode == SetupDeviceMode.caregiver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SetupStepHeading(
          title: caregiver
              ? context.lang.setupCaregiverDataTitle
              : context.lang.setupDataTitle,
          description: caregiver
              ? context.lang.setupCaregiverDataDescription
              : context.lang.setupDataDescription,
        ),
        const SizedBox(height: 16),
        if (!caregiver) ...[
          SettingsSectionCard(
            icon: Icons.hub_outlined,
            title: context.lang.settingsDataSourcesTitle,
            subtitle: context.lang.setupChipsExplanation,
            children: [
              DataSourceConfigControls(
                config: controller.state.config,
                onChanged: controller.setConfig,
                availability: availability,
              ),
              const SizedBox(height: 12),
              SetupFeatureChips(
                features: controller.state.selected.where(
                  (id) =>
                      id == SetupFeatureId.mealMonitor ||
                      id == SetupFeatureId.activityMonitor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsSectionCard(
            icon: Icons.cloud_upload_outlined,
            title: context.lang.setupFamilySharing,
            subtitle: context.lang.setupFamilySharingDescription,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.lang.setupFamilySharing),
                value: controller.state.shareData,
                onChanged: (value) async {
                  if (!value) {
                    final confirmed = await showLocalizedDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(context.lang.setupSharingOffTitle),
                        content: Text(context.lang.setupSharingOffDescription),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.lang.setupBack),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.lang.setupUnderstood),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                  }
                  controller.state.shareData = value;
                  controller.changed();
                },
              ),
              SetupFeatureChips(
                features: controller.state.selected.where(
                  (id) => id == SetupFeatureId.familyChat,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SetupNotice(
          text: caregiver
              ? context.lang.setupCaregiverOffline
              : context.lang.setupLocalWorks,
          icon: Icons.storage_outlined,
        ),
      ],
    );
  }
}
