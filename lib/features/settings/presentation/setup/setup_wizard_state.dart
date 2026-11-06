import '../../../../common/l10n/application_language.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../core/data_sources/config/data_source_config.dart';

class SetupWizardState {
  SetupWizardState({
    required this.config,
    required this.language,
    required this.name,
    required this.nightscoutUrl,
    required this.nightscoutToken,
  });

  DataSourceConfig config;
  ApplicationLanguage language;
  String name;
  String nightscoutUrl;
  String nightscoutToken;
  SetupDeviceMode mode = SetupDeviceMode.patient;
  int step = 0;
  int moduleIndex = 0;
  bool shareData = true;
  bool signedIn = false;
  bool paired = false;
  String aiProvider = 'firebase';
  final selectedByMode = <SetupDeviceMode, Set<SetupFeatureId>>{
    SetupDeviceMode.patient: {
      SetupFeatureId.mealMonitor,
      SetupFeatureId.activityMonitor,
      SetupFeatureId.mealPhoto,
      SetupFeatureId.aiAssistance,
      SetupFeatureId.familyChat,
    },
    SetupDeviceMode.caregiver: {
      SetupFeatureId.familyChat,
      SetupFeatureId.childOverview,
    },
  };
  final granted = <SetupRequirement>{};
  final configured = <SetupModule>{};
  Set<SetupFeatureId> get selected => selectedByMode[mode]!;
}
