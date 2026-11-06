import 'setup_configuration_field.dart';

enum SetupFeatureOptionId {
  lowTreatmentCarbohydrateUpload,
  activityTempTargetUpload,
}

class SetupFeatureOption {
  const SetupFeatureOption({
    required this.id,
    this.requiredConfiguration = const {},
  });
  final SetupFeatureOptionId id;
  final Set<SetupConfigurationField> requiredConfiguration;
}
