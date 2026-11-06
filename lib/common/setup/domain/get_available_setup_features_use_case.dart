import 'setup_configuration_field.dart';
import 'setup_feature.dart';
import 'setup_feature_option.dart';

class GetAvailableSetupFeaturesUseCase {
  const GetAvailableSetupFeaturesUseCase();

  static const catalog = [
    SetupFeature(
      id: SetupFeatureId.mealMonitor,
      modes: {SetupDeviceMode.patient},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.backgroundExecution,
        SetupRequirement.dataSource,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.activityMonitor,
      configurationModule: SetupModule.activity,
      options: [
        SetupFeatureOption(
          id: SetupFeatureOptionId.activityTempTargetUpload,
          requiredConfiguration: {
            SetupConfigurationField.nightscoutUrl,
            SetupConfigurationField.nightscoutToken,
          },
        ),
      ],
      modes: {SetupDeviceMode.patient},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.backgroundExecution,
        SetupRequirement.dataSource,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.mealPhoto,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.camera,
        SetupRequirement.aiConfiguration,
        SetupRequirement.internet,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.aiAssistance,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.aiConfiguration,
        SetupRequirement.internet,
      },
    ),
    // One family feature combines communication with the planned data mirror.
    SetupFeature(
      id: SetupFeatureId.familyChat,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.googleAccount,
        SetupRequirement.familyPairing,
        SetupRequirement.internet,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.childOverview,
      modes: {SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.googleAccount,
        SetupRequirement.familyPairing,
        SetupRequirement.internet,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.lowTreatment,
      alwaysEnabled: true,
      configurationModule: SetupModule.lowTreatment,
      modes: {SetupDeviceMode.patient},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.backgroundExecution,
      },
      options: [
        SetupFeatureOption(
          id: SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
          requiredConfiguration: {
            SetupConfigurationField.nightscoutUrl,
            SetupConfigurationField.nightscoutToken,
          },
        ),
      ],
    ),
  ];

  List<SetupFeature> call(SetupPersonConfiguration person) => List.unmodifiable(
    catalog.where((feature) => feature.modes.contains(person.mode)),
  );
}
