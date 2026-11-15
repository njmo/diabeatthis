import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/setup/domain/setup_feature.dart';
import '../../widgets/settings_section_card.dart';
import '../setup_labels.dart';
import 'setup_feature_chips.dart';

class SetupAccessCard extends StatelessWidget {
  const SetupAccessCard({
    super.key,
    required this.requirement,
    required this.features,
    required this.granted,
    required this.onGrant,
    this.busy = false,
    this.denied = false,
  });
  final SetupRequirement requirement;
  final Set<SetupFeatureId> features;
  final bool granted;
  final bool busy;
  final bool denied;
  final VoidCallback onGrant;
  @override
  Widget build(BuildContext context) => SettingsSectionCard(
    icon: setupRequirementIcon(requirement),
    title: context.lang.requirementName(requirement),
    trailing: OutlinedButton.icon(
      onPressed: granted || busy ? null : onGrant,
      icon: busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              granted ? Icons.check : Icons.add_moderator_outlined,
              size: 18,
            ),
      label: Text(
        requirement == SetupRequirement.exactAlarms && !granted
            ? context.lang.setupOpenSystemSettings
            : context.lang.setupConsent,
      ),
    ),
    children: [
      Text(switch (requirement) {
        SetupRequirement.notifications => context.lang.setupNotificationsWhy,
        SetupRequirement.backgroundExecution => context.lang.setupBackgroundWhy,
        SetupRequirement.exactAlarms => context.lang.setupExactAlarmsWhy,
        SetupRequirement.healthMonitoring =>
          context.lang.setupHealthMonitoringWhy,
        _ => context.lang.setupCameraWhy,
      }, style: Theme.of(context).textTheme.bodySmall),
      if (requirement == SetupRequirement.exactAlarms && !granted)
        Text(
          context.lang.setupExactAlarmsSettingsHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (denied)
        Text(
          context.lang.setupPermissionNotGranted,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      SetupFeatureChips(features: features),
    ],
  );
}
