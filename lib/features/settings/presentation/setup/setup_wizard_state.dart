import '../../../../common/family/family_pairing_invitation.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/l10n/application_language.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
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
  FamilyPairingInvitation? pairingInvitation;
  List<FamilyPairingMember> familyMembers = const [];
  bool generatingInvitation = false;
  bool invitationFailed = false;
  bool familyMembersFailed = false;
  final disconnectingMembers = <String>{};
  bool disconnectFailed = false;
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
  final enabledOptionsByMode = <SetupDeviceMode, Set<SetupFeatureOptionId>>{
    for (final mode in SetupDeviceMode.values) mode: {},
  };
  Set<SetupFeatureOptionId> get enabledOptions => enabledOptionsByMode[mode]!;
  final granted = <SetupRequirement>{};
  final configured = <SetupModule>{};
  Set<SetupFeatureId> get selected => selectedByMode[mode]!;
}
