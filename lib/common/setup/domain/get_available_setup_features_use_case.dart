import 'setup_feature.dart';

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
  ];

  List<SetupFeature> call(SetupPersonConfiguration person) => List.unmodifiable(
    catalog.where((feature) => feature.modes.contains(person.mode)),
  );
}
