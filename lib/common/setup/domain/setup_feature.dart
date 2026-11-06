import 'setup_configuration_field.dart';
import 'setup_feature_group.dart';
import 'setup_feature_option.dart';

enum SetupDeviceMode { patient, caregiver }

enum SetupFeatureId {
  dataAndMeals,
  nightscoutOverview,
  mealPlanning,
  activityPlanning,
  lowTreatmentRecording,
  ingredientLibrary,
  mealHistory,
  mealAnalysis,
  dayOverview,
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
  healthMonitoring,
  exactAlarms,
  camera,
  googleAccount,
  familyPairing,
  internet,
  aiConfiguration,
  dataSource,
}

enum SetupModule {
  data(requiresConfirmation: false, canSkip: false),
  family,
  ai,
  activity(requiresConfirmation: false),
  lowTreatment(requiresConfirmation: false, canSkip: false),
  nightscout;

  const SetupModule({this.requiresConfirmation = true, this.canSkip = true});
  final bool requiresConfirmation;
  final bool canSkip;
}

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
    this.requiredCloudConfiguration = const {},
    this.options = const [],
    this.alwaysEnabled = false,
    this.configurationModule,
    this.group = SetupFeatureGroup.everyday,
    this.wikiPage,
  });
  final SetupFeatureId id;
  final Set<SetupDeviceMode> modes;
  final Set<SetupRequirement> requirements;
  final Set<SetupConfigurationField> requiredConfiguration;
  final Set<SetupConfigurationField> requiredCloudConfiguration;
  final List<SetupFeatureOption> options;
  final bool alwaysEnabled;
  final SetupModule? configurationModule;
  final SetupFeatureGroup group;
  final String? wikiPage;
}
