import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/setup/domain/setup_configuration_field.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';

extension SetupLabels on AppLocalizations {
  String featureName(SetupFeatureId id) => switch (id) {
    SetupFeatureId.mealMonitor => setupFeatureMealName,
    SetupFeatureId.activityMonitor => setupFeatureActivityName,
    SetupFeatureId.mealPhoto => setupFeaturePhotoName,
    SetupFeatureId.aiAssistance => setupFeatureAiName,
    SetupFeatureId.familyChat => setupFeatureFamilyName,
    SetupFeatureId.childOverview => setupFeatureOverviewName,
    SetupFeatureId.lowTreatment => setupFeatureLowTreatmentName,
  };
  String featureDescription(SetupFeatureId id) => switch (id) {
    SetupFeatureId.mealMonitor => setupFeatureMealDescription,
    SetupFeatureId.activityMonitor => setupFeatureActivityDescription,
    SetupFeatureId.mealPhoto => setupFeaturePhotoDescription,
    SetupFeatureId.aiAssistance => setupFeatureAiDescription,
    SetupFeatureId.familyChat => setupFeatureFamilyDescription,
    SetupFeatureId.childOverview => setupFeatureOverviewDescription,
    SetupFeatureId.lowTreatment => setupFeatureLowTreatmentDescription,
  };
  String featureDetails(SetupFeatureId id) => switch (id) {
    SetupFeatureId.mealMonitor => setupFeatureMealDetails,
    SetupFeatureId.activityMonitor => setupFeatureActivityDetails,
    SetupFeatureId.mealPhoto => setupFeaturePhotoDetails,
    SetupFeatureId.aiAssistance => setupFeatureAiDetails,
    SetupFeatureId.familyChat => setupFeatureFamilyDetails,
    SetupFeatureId.childOverview => setupFeatureOverviewDetails,
    SetupFeatureId.lowTreatment => setupFeatureLowTreatmentDetails,
  };
  String requirementName(SetupRequirement requirement) => switch (requirement) {
    SetupRequirement.notifications => setupRequirementNotifications,
    SetupRequirement.backgroundExecution => setupRequirementBackground,
    SetupRequirement.camera => setupRequirementCamera,
    SetupRequirement.googleAccount => setupRequirementGoogle,
    SetupRequirement.familyPairing => setupRequirementPairing,
    SetupRequirement.internet => setupRequirementInternet,
    SetupRequirement.aiConfiguration => setupRequirementAi,
    SetupRequirement.dataSource => setupRequirementData,
  };
  String optionName(SetupFeatureOptionId id) => switch (id) {
    SetupFeatureOptionId.lowTreatmentCarbohydrateUpload =>
      setupFeatureCarbUploadName,
    SetupFeatureOptionId.activityTempTargetUpload =>
      setupFeatureTargetUploadName,
  };
  String optionDescription(SetupFeatureOptionId id) => switch (id) {
    SetupFeatureOptionId.lowTreatmentCarbohydrateUpload =>
      setupFeatureCarbUploadDescription,
    SetupFeatureOptionId.activityTempTargetUpload =>
      setupFeatureTargetUploadDescription,
  };
  String configurationFieldName(SetupConfigurationField field) =>
      switch (field) {
        SetupConfigurationField.nightscoutUrl => setupFieldNightscoutUrl,
        SetupConfigurationField.nightscoutToken => setupFieldNightscoutToken,
      };
  String moduleName(SetupModule? module) => switch (module) {
    SetupModule.family => setupModuleFamily,
    SetupModule.ai => setupModuleAi,
    SetupModule.activity => setupModuleActivity,
    SetupModule.lowTreatment => setupModuleLowTreatment,
    SetupModule.nightscout => setupModuleNightscout,
    null => setupStepConfiguration,
  };
}

IconData setupFeatureIcon(SetupFeatureId id) => switch (id) {
  SetupFeatureId.mealMonitor => Icons.restaurant_outlined,
  SetupFeatureId.activityMonitor => Icons.directions_bike_outlined,
  SetupFeatureId.mealPhoto => Icons.camera_alt_outlined,
  SetupFeatureId.aiAssistance => Icons.auto_awesome_outlined,
  SetupFeatureId.familyChat => Icons.forum_outlined,
  SetupFeatureId.childOverview => Icons.calendar_month_outlined,
  SetupFeatureId.lowTreatment => Icons.emergency_outlined,
};

IconData setupRequirementIcon(SetupRequirement requirement) =>
    switch (requirement) {
      SetupRequirement.notifications => Icons.notifications_outlined,
      SetupRequirement.backgroundExecution =>
        Icons.battery_charging_full_outlined,
      SetupRequirement.camera => Icons.camera_alt_outlined,
      SetupRequirement.googleAccount => Icons.account_circle_outlined,
      SetupRequirement.familyPairing => Icons.qr_code_scanner,
      SetupRequirement.internet => Icons.wifi,
      SetupRequirement.aiConfiguration => Icons.auto_awesome_outlined,
      SetupRequirement.dataSource => Icons.sensors,
    };

bool isSetupSystemRequirement(SetupRequirement requirement) => {
  SetupRequirement.notifications,
  SetupRequirement.backgroundExecution,
  SetupRequirement.camera,
}.contains(requirement);
