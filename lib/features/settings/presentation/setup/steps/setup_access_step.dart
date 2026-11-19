import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/notification_retry_switch.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_labels.dart';
import '../setup_wizard_controller.dart';
import '../widgets/setup_access_card.dart';
import '../widgets/setup_notice.dart';
import '../widgets/setup_step_heading.dart';

class SetupAccessStep extends StatelessWidget {
  const SetupAccessStep({
    super.key,
    required this.controller,
    required this.accessCardKeys,
  });
  final Map<SetupRequirement, GlobalKey> accessCardKeys;
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
        Text(
          permissions.isEmpty
              ? context.lang.setupNoRequirements
              : context.lang.setupPermissionsProgress(
                  permissions
                      .where(
                        (entry) => controller.state.granted.contains(entry.key),
                      )
                      .length,
                  permissions.length,
                ),
        ),
        const SizedBox(height: 16),
        for (final entry in permissions)
          Padding(
            key: accessCardKeys.putIfAbsent(entry.key, () => GlobalKey()),
            padding: const EdgeInsets.only(bottom: 14),
            child: SetupAccessCard(
              requirement: entry.key,
              features: entry.value,
              granted: controller.state.granted.contains(entry.key),
              busy: controller.state.requestingPermissions.contains(entry.key),
              denied: controller.state.deniedPermissions.contains(entry.key),
              onGrant: () => controller.grant(entry.key),
            ),
          ),
        SettingsSectionCard(
          title: context.lang.notificationSettingsTitle,
          icon: Icons.notifications_outlined,
          children: [
            NotificationRetrySwitch(
              value: controller.state.notificationRetriesEnabled,
              onChanged: controller.setNotificationRetriesEnabled,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SetupNotice(
          text: controller.permissions == null
              ? context.lang.setupDemoNotice
              : context.lang.setupPermissionsLiveNotice,
        ),
      ],
    );
  }
}
