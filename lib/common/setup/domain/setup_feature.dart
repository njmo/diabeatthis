import 'setup_configuration_field.dart';
import 'setup_feature_option.dart';

enum SetupDeviceMode { patient, caregiver }

enum SetupFeatureId {
  mealMonitor,
  activityMonitor,
  mealPhoto,
  aiAssistance,
  familyChat,
  childOverview,
  lowTreatment,
}

enum SetupRequirement {
  notifications,
  backgroundExecution,
  camera,
  googleAccount,
  familyPairing,
  internet,
  aiConfiguration,
  dataSource,
}

enum SetupModule { family, ai, activity, lowTreatment, nightscout }

class SetupPersonConfiguration {
  const SetupPersonConfiguration({required this.mode});
  final SetupDeviceMode mode;
}

class SetupFeature {
  const SetupFeature({
    required this.id,
    required this.modes,
    required this.requirements,
    this.requiredConfiguration = const {},
    this.options = const [],
    this.alwaysEnabled = false,
    this.configurationModule,
  });
  final SetupFeatureId id;
  final Set<SetupDeviceMode> modes;
  final Set<SetupRequirement> requirements;
  final Set<SetupConfigurationField> requiredConfiguration;
  final List<SetupFeatureOption> options;
  final bool alwaysEnabled;
  final SetupModule? configurationModule;
}
