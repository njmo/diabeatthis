import '../../../../common/auth/google_account.dart';
import '../../../../common/family/family_pairing_invitation.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/l10n/application_language.dart';
import '../../../../common/meal_advisor/meal_decision_preferences.dart';
import '../../../../common/setup/domain/setup_account_choice.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../common/setup/domain/setup_step.dart';
import '../../../../common/setup/domain/validate_setup_module_use_case.dart';
import '../../../../core/data_sources/config/data_source_config.dart';

class SetupWizardState {
  SetupWizardState({
    required this.config,
    required this.language,
    required this.name,
    required this.nightscoutUrl,
    required this.nightscoutToken,
    this.mealDecisionPreferences = const MealDecisionPreferences(),
    Set<SetupFeatureOptionId> initialOptions = const {},
  }) {
    enabledOptionsByMode[SetupDeviceMode.patient]!.addAll(initialOptions);
  }

  MealDecisionPreferences mealDecisionPreferences;
  DataSourceConfig config;
  ApplicationLanguage language;
  String name;
  String nightscoutUrl;
  String nightscoutToken;
  SetupNightscoutVerification? nightscoutVerification;
  SetupDeviceMode mode = SetupDeviceMode.patient;
  int step = 0;
  SetupStep get currentStep =>
      SetupStep.values[step.clamp(0, SetupStep.values.length - 1)];
  final attemptedModules = <SetupModule>{};
  bool moduleValidationFailed = false;
  int moduleIndex = 0;

  /// Family communication and the future data mirror share one feature switch.
  bool get shareData =>
      selected.contains(SetupFeatureId.familyChat) &&
      (!requireGoogleForFamily || signedIn);
  bool requireGoogleForFamily = false;
  SetupAccountChoice accountChoice = SetupAccountChoice.undecided;
  GoogleAccount? googleAccount;
  bool signingIn = false;
  bool signInFailed = false;
  final requestingPermissions = <SetupRequirement>{};
  final deniedPermissions = <SetupRequirement>{};
  bool signedIn = false;
  bool paired = false;
  FamilyPairingInvitation? pairingInvitation;
  List<FamilyPairingMember> familyMembers = const [];
  bool generatingInvitation = false;
  bool invitationFailed = false;
  bool familyMembersFailed = false;
  final disconnectingMembers = <String>{};
  bool disconnectFailed = false;
  final selectedByMode = <SetupDeviceMode, Set<SetupFeatureId>>{
    SetupDeviceMode.patient: {
      SetupFeatureId.mealMonitor,
      SetupFeatureId.activityMonitor,
      SetupFeatureId.mealPhoto,
      SetupFeatureId.aiAssistance,
      SetupFeatureId.familyChat,
    },
    SetupDeviceMode.caregiver: {
      SetupFeatureId.caregiverMealDecisions,
      SetupFeatureId.aiAssistance,
      SetupFeatureId.mealPhoto,
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
