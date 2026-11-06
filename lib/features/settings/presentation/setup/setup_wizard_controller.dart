import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../common/auth/google_account.dart';
import '../../../../common/auth/google_authentication_repository.dart';
import '../../../../common/family/demo_family_pairing_repository.dart';
import '../../../../common/family/family_management_context.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/family/family_pairing_repository.dart';
import '../../../../common/family/use_cases/create_family_invitation_use_case.dart';
import '../../../../common/family/use_cases/disconnect_family_member_use_case.dart';
import '../../../../common/family/use_cases/simulate_family_pairing_use_case.dart';
import '../../../../common/family/use_cases/watch_family_members_use_case.dart';
import '../../../../common/forms/form_submission_controller.dart';
import '../../../../common/setup/domain/collect_setup_configuration_fields_use_case.dart';
import '../../../../common/setup/domain/collect_setup_requirements_use_case.dart';
import '../../../../common/setup/domain/get_available_setup_features_use_case.dart';
import '../../../../common/setup/domain/setup_account_choice.dart';
import '../../../../common/setup/domain/setup_configuration_field.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../common/setup/domain/setup_permission_gateway.dart';
import '../../../../common/setup/domain/setup_step.dart';
import '../../../../common/setup/domain/validate_setup_configuration_use_case.dart';
import '../../../../common/setup/domain/validate_setup_module_use_case.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import 'setup_wizard_state.dart';

/// Coordinates setup choices with optional live account and permission adapters.
class SetupWizardController extends ChangeNotifier {
  SetupWizardController(
    this.state, {
    FamilyPairingRepository? familyRepository,
    this.familyContext = FamilyManagementContext.settings,
    this.checkNightscoutConnection,
    this.authentication,
    this.permissions,
  }) : familyRepository = familyRepository ?? DemoFamilyPairingRepository(),
       ownsFamilyRepository = familyRepository == null {
    aiSubmission.addListener(changed);
    state.requireGoogleForFamily = authentication != null;
    if (authentication != null) {
      try {
        accountSubscription = authentication!.watchAccount().listen(
          applyGoogleAccount,
          onError: (Object error) {
            if (!disposed) {
              applyGoogleAccount(null);
              state.signInFailed = true;
              changed();
            }
          },
        );
      } catch (_) {
        state.signInFailed = true;
      }
    }
  }
  final FormSubmissionController aiSubmission = FormSubmissionController();
  final GoogleAuthenticationRepository? authentication;
  final SetupPermissionGateway? permissions;
  StreamSubscription<GoogleAccount?>? accountSubscription;
  final permissionRevisions = <SetupRequirement, int>{};
  String? nameBeforeGoogle;
  bool restorePatientFamilyAfterSignIn = false;

  void applyGoogleAccount(GoogleAccount? account) {
    if (disposed) return;
    if (state.googleAccount?.uid == account?.uid &&
        state.signedIn == (account != null)) {
      if (account != null) {
        state.googleAccount = account;
        if (account.label.isNotEmpty) state.name = account.label;
        changed();
      }
      return;
    }
    pairingSession++;
    unawaited(familySubscription?.cancel());
    familySubscription = null;
    if (familyRepository is DemoFamilyPairingRepository) {
      (familyRepository as DemoFamilyPairingRepository).reset();
    }
    if (account != null) {
      if (restorePatientFamilyAfterSignIn) {
        state.selectedByMode[SetupDeviceMode.patient]!.add(
          SetupFeatureId.familyChat,
        );
        restorePatientFamilyAfterSignIn = false;
        configurationRevision++;
      }
      if (state.googleAccount == null) nameBeforeGoogle = state.name;
      state.name = account.label.isNotEmpty ? account.label : state.name;
      state.accountChoice = SetupAccountChoice.google;
    } else {
      if (nameBeforeGoogle != null) state.name = nameBeforeGoogle!;
      state.accountChoice = SetupAccountChoice.undecided;
    }
    state.googleAccount = account;
    state.signedIn = account != null;
    if (account == null &&
        authentication != null &&
        state.mode == SetupDeviceMode.caregiver) {
      state.mode = SetupDeviceMode.patient;
      state.moduleIndex = 0;
      configurationRevision++;
    }
    state.familyMembers = const [];
    state.pairingInvitation = null;
    state.paired = false;
    state.generatingInvitation = false;
    state.invitationFailed = false;
    state.disconnectingMembers.clear();
    state.configured.remove(SetupModule.family);
    if (account != null) {
      refreshFamilyMembers();
      unawaited(generatePairingInvitation());
    }
    changed();
  }

  Future<void> signInGoogle() async {
    if (authentication == null) {
      simulateSignIn();
      return;
    }
    if (disposed || state.signingIn) return;
    state.signingIn = true;
    state.signInFailed = false;
    changed();
    final session = pairingSession;
    try {
      final account = await authentication!.signIn();
      if (!disposed && account != null && session == pairingSession) {
        applyGoogleAccount(account);
      }
    } catch (_) {
      if (!disposed) state.signInFailed = true;
    } finally {
      if (!disposed) {
        state.signingIn = false;
        changed();
      }
    }
  }

  Future<void> continueWithoutGoogle() async {
    if (disposed ||
        state.signingIn ||
        (state.mode != SetupDeviceMode.patient &&
            state.currentStep != SetupStep.start)) {
      return;
    }
    if (authentication != null) {
      state.signingIn = true;
      state.signInFailed = false;
      changed();
      try {
        await authentication!.signOut();
      } catch (_) {
        if (!disposed) {
          state.signingIn = false;
          state.signInFailed = true;
          changed();
        }
        return;
      }
      if (disposed) return;
      applyGoogleAccount(null);
      state.signingIn = false;
    }
    state.accountChoice = SetupAccountChoice.local;
    restorePatientFamilyAfterSignIn =
        restorePatientFamilyAfterSignIn ||
        state.selectedByMode[SetupDeviceMode.patient]!.contains(
          SetupFeatureId.familyChat,
        );
    state.selectedByMode[SetupDeviceMode.patient]!.remove(
      SetupFeatureId.familyChat,
    );
    state.configured.remove(SetupModule.family);
    changed();
  }

  Future<void> signOutGoogle() async {
    if (disposed || authentication == null || state.signingIn) return;
    state.signingIn = true;
    state.signInFailed = false;
    changed();
    final uid = state.googleAccount?.uid;
    try {
      await authentication!.signOut();
      if (!disposed && state.googleAccount?.uid == uid) {
        applyGoogleAccount(null);
      }
    } catch (_) {
      if (!disposed) state.signInFailed = true;
    } finally {
      if (!disposed) {
        state.signingIn = false;
        changed();
      }
    }
  }

  Future<void> refreshPermissions() async {
    if (permissions == null || disposed) return;
    for (final requirement in requirements.keys.toList()) {
      if (![
        SetupRequirement.notifications,
        SetupRequirement.healthMonitoring,
        SetupRequirement.camera,
        SetupRequirement.backgroundExecution,
        SetupRequirement.exactAlarms,
      ].contains(requirement)) {
        continue;
      }
      if (state.requestingPermissions.contains(requirement)) continue;
      final revision = (permissionRevisions[requirement] ?? 0) + 1;
      permissionRevisions[requirement] = revision;
      try {
        final granted = await permissions!.check(requirement);
        if (disposed) return;
        if (revision != (permissionRevisions[requirement] ?? 0)) continue;
        if (granted) {
          state.granted.add(requirement);
          state.deniedPermissions.remove(requirement);
        } else {
          state.granted.remove(requirement);
        }
      } catch (_) {
        if (disposed) return;
      }
    }
    if (!disposed) changed();
  }

  final FamilyPairingRepository familyRepository;
  final SetupConnectionValidator? checkNightscoutConnection;
  bool isValidating = false;
  int configurationRevision = 0;
  final bool ownsFamilyRepository;
  final FamilyManagementContext familyContext;
  late final createFamilyInvitation = CreateFamilyInvitationUseCase(
    familyRepository,
  );
  late final watchFamilyMembers = WatchFamilyMembersUseCase(familyRepository);
  late final disconnectFamilyMember = DisconnectFamilyMemberUseCase(
    familyRepository,
  );
  late final simulateFamilyPairing = SimulateFamilyPairingUseCase(
    familyRepository,
  );
  bool get canDisconnectFamily =>
      state.signedIn &&
      !state.familyMembersFailed &&
      disconnectFamilyMember.canDisconnect(state.mode, familyContext);

  Future<void> disconnectMember(String memberId) async {
    if (disposed ||
        !canDisconnectFamily ||
        state.disconnectingMembers.contains(memberId) ||
        !state.familyMembers.any((member) => member.id == memberId)) {
      return;
    }
    final session = pairingSession;
    final mode = state.mode;
    state.disconnectingMembers.add(memberId);
    state.disconnectFailed = false;
    changed();
    try {
      await disconnectFamilyMember(mode, memberId, familyContext);
    } catch (_) {
      if (!disposed && session == pairingSession) state.disconnectFailed = true;
    } finally {
      if (!disposed && session == pairingSession) {
        state.disconnectingMembers.remove(memberId);
        changed();
      }
    }
  }

  StreamSubscription<List<FamilyPairingMember>>? familySubscription;
  bool disposed = false;
  int pairingSession = 0;
  int invitationRequest = 0;
  int membershipRequest = 0;

  @override
  void dispose() {
    disposed = true;
    aiSubmission.removeListener(changed);
    aiSubmission.dispose();
    unawaited(accountSubscription?.cancel());
    unawaited(familySubscription?.cancel());
    if (ownsFamilyRepository &&
        familyRepository is DemoFamilyPairingRepository) {
      (familyRepository as DemoFamilyPairingRepository).dispose();
    }
    super.dispose();
  }

  bool get invitationUsed =>
      state.pairingInvitation != null &&
      state.familyMembers.any(
        (member) => member.invitationId == state.pairingInvitation!.id,
      );

  Future<void> generatePairingInvitation() async {
    if (!state.signedIn || state.generatingInvitation || disposed) return;
    final session = pairingSession, request = ++invitationRequest;
    final mode = state.mode;
    state.generatingInvitation = true;
    state.invitationFailed = false;
    changed();
    try {
      final invitation = await createFamilyInvitation(mode);
      if (disposed ||
          session != pairingSession ||
          request != invitationRequest) {
        return;
      }
      state.pairingInvitation = invitation;
    } catch (_) {
      if (disposed ||
          session != pairingSession ||
          request != invitationRequest) {
        return;
      }
      state.invitationFailed = true;
    } finally {
      if (!disposed &&
          session == pairingSession &&
          request == invitationRequest) {
        state.generatingInvitation = false;
        changed();
      }
    }
  }

  final SetupWizardState state;

  List<SetupFeature> get available => const GetAvailableSetupFeaturesUseCase()(
    SetupPersonConfiguration(mode: state.mode),
  );
  List<SetupFeature> get selected => available
      .where(
        (feature) =>
            (feature.alwaysEnabled || state.selected.contains(feature.id)) &&
            canEnableFeature(feature.id),
      )
      .toList();
  Map<SetupRequirement, Set<SetupFeatureId>> get requirements =>
      const CollectSetupRequirementsUseCase()(selected);
  Map<SetupConfigurationField, Set<SetupFeatureId>> get requiredConfiguration =>
      const CollectSetupConfigurationFieldsUseCase()(
        selected,
        enabledOptions: state.enabledOptions,
        usesCloudData:
            state.mode == SetupDeviceMode.patient && state.config.usesCloud,
      );
  Set<SetupConfigurationField> get missingConfiguration =>
      const ValidateSetupConfigurationUseCase()(
        requiredFields: requiredConfiguration.keys,
        values: {
          SetupConfigurationField.nightscoutUrl: state.nightscoutUrl,
          SetupConfigurationField.nightscoutToken: state.nightscoutToken,
        },
      );
  bool configurationComplete(SetupModule module) =>
      !missingConfiguration.any((field) => field.module == module);
  bool moduleReady(SetupModule module) =>
      (!module.requiresConfirmation || state.configured.contains(module)) &&
      configurationComplete(module);
  SetupModule? get incompleteRequiredConfigurationModule {
    for (final field in requiredConfiguration.keys) {
      if (!moduleReady(field.module)) return field.module;
    }
    return null;
  }

  List<SetupModule> get modules => [
    ...selected
        .map((feature) => feature.configurationModule)
        .whereType<SetupModule>()
        .toSet(),
    if (requirements.containsKey(SetupRequirement.familyPairing))
      SetupModule.family,
    if (requirements.containsKey(SetupRequirement.aiConfiguration))
      SetupModule.ai,
    if (state.mode == SetupDeviceMode.patient &&
        (state.config.usesCloud ||
            requiredConfiguration.keys.any(
              (field) => field.module == SetupModule.nightscout,
            )))
      SetupModule.nightscout,
  ];
  SetupModule? get module => modules.isEmpty
      ? null
      : modules[state.moduleIndex.clamp(0, modules.length - 1)];

  void changed() {
    if (!disposed) notifyListeners();
  }

  bool canUseMode(SetupDeviceMode mode) =>
      mode == SetupDeviceMode.patient ||
      authentication == null ||
      state.signedIn;
  bool canEnableFeature(SetupFeatureId id) =>
      authentication == null ||
      state.signedIn ||
      !available
          .firstWhere((feature) => feature.id == id)
          .requirements
          .contains(SetupRequirement.googleAccount);

  void setMode(SetupDeviceMode mode) {
    if (!canUseMode(mode)) return;
    if (disposed || state.signingIn) return;
    if (state.mode == mode) return;
    configurationRevision++;
    state.moduleValidationFailed = false;
    state.attemptedModules.clear();
    if (state.googleAccount != null) {
      state.accountChoice = SetupAccountChoice.google;
    }
    state.mode = mode;
    state.moduleIndex = 0;
    pairingSession++;
    unawaited(familySubscription?.cancel());
    familySubscription = null;
    state.signedIn = authentication != null && state.googleAccount != null;
    state.paired = false;
    state.pairingInvitation = null;
    state.familyMembers = const [];
    state.generatingInvitation = false;
    state.invitationFailed = false;
    state.familyMembersFailed = false;
    state.disconnectingMembers.clear();
    state.disconnectFailed = false;
    state.configured.remove(SetupModule.family);
    if (state.signedIn) {
      refreshFamilyMembers();
      unawaited(generatePairingInvitation());
    }
    changed();
  }

  void select(SetupFeatureId id, bool enabled) {
    if (enabled && !canEnableFeature(id)) return;
    if (id == SetupFeatureId.familyChat &&
        state.mode == SetupDeviceMode.patient) {
      restorePatientFamilyAfterSignIn = false;
    }
    if (available.any((feature) => feature.id == id && feature.alwaysEnabled)) {
      return;
    }
    configurationRevision++;
    if (enabled) {
      state.selected.add(id);
    } else {
      state.selected.remove(id);
    }
    state.configured.removeWhere((module) => !configurationComplete(module));
    state.moduleIndex = 0;
    changed();
  }

  void selectOption(SetupFeatureOptionId id, bool enabled) {
    if (!selected.any(
      (feature) => feature.options.any((option) => option.id == id),
    )) {
      return;
    }
    configurationRevision++;
    if (enabled) {
      state.enabledOptions.add(id);
    } else {
      state.enabledOptions.remove(id);
    }
    for (final feature in selected.where(
      (feature) => feature.options.any((option) => option.id == id),
    )) {
      state.configured.remove(feature.configurationModule);
    }
    state.configured.removeWhere((module) => !configurationComplete(module));
    changed();
  }

  void setConfig(DataSourceConfig config) {
    if (config == state.config) return;
    configurationRevision++;
    state.config = config;
    state.configured.remove(SetupModule.nightscout);
    state.moduleValidationFailed = false;
    state.moduleIndex = 0;
    changed();
  }

  void setNightscout(String url, String token) {
    configurationRevision++;
    state.nightscoutUrl = url;
    state.nightscoutToken = token;
    state.moduleValidationFailed = false;
    state.configured.remove(SetupModule.nightscout);
    changed();
  }

  void goTo(int step) {
    state.step = step.clamp(0, SetupStep.values.length - 1);
    changed();
  }

  void back() {
    if (state.signingIn || disposed) return;
    if (state.currentStep == SetupStep.summary) {
      state.step = SetupStep.configuration.index;
      state.moduleIndex = modules.isEmpty ? 0 : modules.length - 1;
    } else if (state.currentStep == SetupStep.configuration &&
        state.moduleIndex > 0) {
      state.moduleIndex--;
    } else if (state.step > 0) {
      state.step--;
    }
    changed();
  }

  bool next() {
    if (state.signingIn || disposed) return false;
    if (state.currentStep == SetupStep.configuration &&
        module != null &&
        !moduleReady(module!)) {
      return false;
    }
    if (state.currentStep == SetupStep.configuration &&
        state.moduleIndex + 1 < modules.length) {
      state.moduleIndex++;
    } else if (state.step < SetupStep.summary.index) {
      state.step++;
    }
    changed();
    return true;
  }

  Future<bool> validateAndNext() async {
    if (disposed || isValidating || state.signingIn) return false;
    if (authentication != null && !state.signedIn) {
      if (state.currentStep == SetupStep.start &&
          state.accountChoice != SetupAccountChoice.local) {
        return false;
      }
      if (state.currentStep == SetupStep.role &&
          state.mode == SetupDeviceMode.caregiver) {
        return false;
      }
    }
    if (state.currentStep == SetupStep.access && permissions != null) {
      await refreshPermissions();
      if (disposed) return false;
      final missing = requirements.keys.where(
        (requirement) =>
            [
              SetupRequirement.notifications,
              SetupRequirement.healthMonitoring,
              SetupRequirement.camera,
              SetupRequirement.backgroundExecution,
              SetupRequirement.exactAlarms,
            ].contains(requirement) &&
            !state.granted.contains(requirement),
      );
      if (missing.isNotEmpty || state.requestingPermissions.isNotEmpty) {
        return false;
      }
    }
    final current = module;
    if (state.currentStep != SetupStep.configuration || current == null) {
      return next();
    }
    final revision = configurationRevision;
    final session = pairingSession;
    isValidating = true;
    state.attemptedModules.add(current);
    state.moduleValidationFailed = false;
    changed();
    try {
      final submittingAi = current == SetupModule.ai && aiSubmission.isAttached;
      final valid =
          current == SetupModule.ai && (authentication != null || submittingAi)
          ? await aiSubmission.submit()
          : await const ValidateSetupModuleUseCase()(
              requiredFields: requiredConfiguration.keys.where(
                (field) => field.module == current,
              ),
              values: {
                SetupConfigurationField.nightscoutUrl: state.nightscoutUrl,
                SetupConfigurationField.nightscoutToken: state.nightscoutToken,
              },
              validateNightscout: current == SetupModule.nightscout,
              requiresWrite: requiredConfiguration.containsKey(
                SetupConfigurationField.nightscoutToken,
              ),
              checkConnection: checkNightscoutConnection,
            );
      if (disposed ||
          session != pairingSession ||
          revision != configurationRevision ||
          module != current ||
          state.currentStep != SetupStep.configuration) {
        return false;
      }
      if (!valid) {
        state.moduleValidationFailed = true;
        return false;
      }
      if (current == SetupModule.nightscout || submittingAi) {
        state.configured.add(current);
      }
      return next();
    } catch (_) {
      if (!disposed &&
          session == pairingSession &&
          revision == configurationRevision) {
        state.moduleValidationFailed = true;
      }
      return false;
    } finally {
      isValidating = false;
      if (!disposed) changed();
    }
  }

  Future<void> grant(SetupRequirement requirement) async {
    if (disposed || state.requestingPermissions.contains(requirement)) return;
    if (permissions == null) {
      state.granted.add(requirement);
      changed();
      return;
    }
    permissionRevisions[requirement] =
        (permissionRevisions[requirement] ?? 0) + 1;
    state.requestingPermissions.add(requirement);
    state.deniedPermissions.remove(requirement);
    changed();
    try {
      final granted = await permissions!.request(requirement);
      if (!disposed) {
        if (granted) {
          state.granted.add(requirement);
        } else {
          state.granted.remove(requirement);
          state.deniedPermissions.add(requirement);
        }
      }
    } catch (_) {
      if (!disposed) {
        state.granted.remove(requirement);
        state.deniedPermissions.add(requirement);
      }
    } finally {
      if (!disposed) {
        state.requestingPermissions.remove(requirement);
        changed();
      }
    }
  }

  void simulateSignIn() {
    if (state.signedIn || disposed || authentication != null) return;
    state.signedIn = true;
    pairingSession++;
    refreshFamilyMembers();
    unawaited(generatePairingInvitation());
  }

  void refreshFamilyMembers() {
    if (!state.signedIn || disposed) return;
    final session = pairingSession, request = ++membershipRequest;
    unawaited(familySubscription?.cancel());
    state.familyMembers = const [];
    state.paired = false;
    state.configured.remove(SetupModule.family);
    state.familyMembersFailed = false;
    void failed() {
      if (disposed ||
          session != pairingSession ||
          request != membershipRequest) {
        return;
      }
      state.familyMembersFailed = true;
      state.familyMembers = const [];
      state.paired = false;
      state.configured.remove(SetupModule.family);
      changed();
    }

    try {
      familySubscription = watchFamilyMembers(state.mode).listen(
        (members) {
          if (disposed ||
              session != pairingSession ||
              request != membershipRequest) {
            return;
          }
          final invitationWasUsed = invitationUsed;
          state.familyMembers = List.unmodifiable(members);
          if (invitationWasUsed && !invitationUsed) {
            state.pairingInvitation = null;
          }
          state.paired = members.isNotEmpty;
          state.familyMembersFailed = false;
          if (state.paired) {
            state.configured.add(SetupModule.family);
          } else {
            state.configured.remove(SetupModule.family);
          }
          changed();
        },
        onError: (Object error) => failed(),
        onDone: failed,
      );
    } catch (_) {
      failed();
    }
    changed();
  }

  void simulatePairing() {
    if (!state.signedIn || disposed) return;
    simulateFamilyPairing(state.mode);
  }

  void invalidateModule(SetupModule module) {
    if (disposed) return;
    configurationRevision++;
    state.configured.remove(module);
    changed();
  }

  void simulateModule(SetupModule module) => completeModule(module);

  void completeModule(SetupModule module) {
    if (disposed || !configurationComplete(module)) return;
    state.configured.add(module);
    changed();
  }

  void skipModule() {
    final current = module;
    if (current == null) return;
    if (!current.canSkip) return;
    switch (current) {
      case SetupModule.data:
        return;
      case SetupModule.family:
        state.selected.removeAll({
          SetupFeatureId.familyChat,
          SetupFeatureId.childOverview,
        });
      case SetupModule.ai:
        state.selected.removeAll({
          SetupFeatureId.mealPhoto,
          SetupFeatureId.aiAssistance,
        });
      case SetupModule.activity:
        state.selected.remove(SetupFeatureId.activityMonitor);
      case SetupModule.lowTreatment:
        return; // Core low treatment monitoring cannot be disabled.
      case SetupModule.nightscout:
        if (state.config.usesCloud) return;
        for (final feature in selected) {
          for (final option in feature.options) {
            if (option.requiredConfiguration.any(
              (field) => field.module == SetupModule.nightscout,
            )) {
              state.enabledOptions.remove(option.id);
            }
          }
        }
        state.configured.remove(SetupModule.nightscout);
    }
    if (state.moduleIndex >= modules.length) {
      state.step = SetupStep.summary.index;
      state.moduleIndex = 0;
    }
    changed();
  }
}
