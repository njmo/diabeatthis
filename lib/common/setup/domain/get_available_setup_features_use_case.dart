import 'setup_configuration_field.dart';
import 'setup_feature.dart';
import 'setup_feature_group.dart';
import 'setup_feature_option.dart';

class GetAvailableSetupFeaturesUseCase {
  const GetAvailableSetupFeaturesUseCase();

  static const catalog = [
    SetupFeature(
      id: SetupFeatureId.nightscoutOverview,
      modes: {SetupDeviceMode.caregiver},
      requirements: {SetupRequirement.internet, SetupRequirement.dataSource},
      requiredConfiguration: {SetupConfigurationField.nightscoutUrl},
      alwaysEnabled: true,
    ),
    SetupFeature(
      id: SetupFeatureId.dataAndMeals,
      wikiPage: 'First-setup',
      modes: {SetupDeviceMode.patient},
      requirements: {SetupRequirement.dataSource},
      alwaysEnabled: true,
      configurationModule: SetupModule.data,
      requiredCloudConfiguration: {SetupConfigurationField.nightscoutUrl},
    ),
    SetupFeature(
      id: SetupFeatureId.mealPlanning,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.everyday,
      wikiPage: 'Meals',
    ),
    SetupFeature(
      id: SetupFeatureId.activityPlanning,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.everyday,
      wikiPage: 'Activity',
    ),
    SetupFeature(
      id: SetupFeatureId.lowTreatmentRecording,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.everyday,
      wikiPage: 'Low-treatments',
    ),
    SetupFeature(
      id: SetupFeatureId.ingredientLibrary,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.everyday,
      wikiPage: 'Ingredients',
    ),
    SetupFeature(
      id: SetupFeatureId.mealHistory,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.history,
      wikiPage: 'Meals',
    ),
    SetupFeature(
      id: SetupFeatureId.mealAnalysis,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.history,
      wikiPage: 'Meals',
    ),
    SetupFeature(
      id: SetupFeatureId.dayOverview,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.history,
      wikiPage: 'Day-overview',
    ),
    SetupFeature(
      id: SetupFeatureId.mealMonitor,
      wikiPage: 'Meals',
      group: SetupFeatureGroup.monitoring,
      modes: {SetupDeviceMode.patient},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.exactAlarms,
        SetupRequirement.backgroundExecution,
        SetupRequirement.healthMonitoring,
        SetupRequirement.dataSource,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.activityMonitor,
      wikiPage: 'Activity',
      group: SetupFeatureGroup.monitoring,
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
        SetupRequirement.exactAlarms,
        SetupRequirement.backgroundExecution,
        SetupRequirement.healthMonitoring,
        SetupRequirement.dataSource,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.lowTreatment,
      wikiPage: 'Low-treatments',
      group: SetupFeatureGroup.monitoring,
      alwaysEnabled: true,
      configurationModule: SetupModule.lowTreatment,
      modes: {SetupDeviceMode.patient},
      requirements: {
        SetupRequirement.notifications,
        SetupRequirement.backgroundExecution,
        SetupRequirement.healthMonitoring,
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
    SetupFeature(
      id: SetupFeatureId.familyChat,
      group: SetupFeatureGroup.family,
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
      group: SetupFeatureGroup.family,
      modes: {SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.googleAccount,
        SetupRequirement.familyPairing,
        SetupRequirement.internet,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.mealAdvisor,
      modes: {SetupDeviceMode.patient},
      requirements: {},
      alwaysEnabled: true,
      group: SetupFeatureGroup.assistance,
      configurationModule: SetupModule.mealAdvisor,
      wikiPage: 'Meals',
    ),
    SetupFeature(
      id: SetupFeatureId.caregiverMealDecisions,
      modes: {SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.googleAccount,
        SetupRequirement.familyPairing,
        SetupRequirement.internet,
        SetupRequirement.notifications,
      },
      group: SetupFeatureGroup.family,
      configurationModule: SetupModule.mealAdvisor,
      wikiPage: 'Meals',
    ),
    SetupFeature(
      id: SetupFeatureId.aiAssistance,
      wikiPage: 'AI',
      group: SetupFeatureGroup.assistance,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.aiConfiguration,
        SetupRequirement.internet,
      },
    ),
    SetupFeature(
      id: SetupFeatureId.mealPhoto,
      wikiPage: 'AI',
      group: SetupFeatureGroup.assistance,
      modes: {SetupDeviceMode.patient, SetupDeviceMode.caregiver},
      requirements: {
        SetupRequirement.camera,
        SetupRequirement.aiConfiguration,
        SetupRequirement.internet,
      },
    ),
  ];

  List<SetupFeature> call(SetupPersonConfiguration person) => List.unmodifiable(
    catalog.where((feature) => feature.modes.contains(person.mode)),
  );
}
