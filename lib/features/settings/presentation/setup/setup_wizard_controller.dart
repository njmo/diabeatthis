import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../common/family/demo_family_pairing_repository.dart';
import '../../../../common/family/family_management_context.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/family/family_pairing_repository.dart';
import '../../../../common/family/use_cases/create_family_invitation_use_case.dart';
import '../../../../common/family/use_cases/disconnect_family_member_use_case.dart';
import '../../../../common/family/use_cases/simulate_family_pairing_use_case.dart';
import '../../../../common/family/use_cases/watch_family_members_use_case.dart';
import '../../../../common/setup/domain/collect_setup_configuration_fields_use_case.dart';
import '../../../../common/setup/domain/collect_setup_requirements_use_case.dart';
import '../../../../common/setup/domain/get_available_setup_features_use_case.dart';
import '../../../../common/setup/domain/setup_configuration_field.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../common/setup/domain/validate_setup_configuration_use_case.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import 'setup_wizard_state.dart';

/// Session-only demo choices. Never starts services or writes preferences.
class SetupWizardController extends ChangeNotifier {
  SetupWizardController(
    this.state, {
    FamilyPairingRepository? familyRepository,
    this.familyContext = FamilyManagementContext.settings,
  }) : familyRepository = familyRepository ?? DemoFamilyPairingRepository(),
       ownsFamilyRepository = familyRepository == null;
  final FamilyPairingRepository familyRepository;
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
            feature.alwaysEnabled || state.selected.contains(feature.id),
      )
      .toList();
  Map<SetupRequirement, Set<SetupFeatureId>> get requirements =>
      const CollectSetupRequirementsUseCase()(selected);
  Map<SetupConfigurationField, Set<SetupFeatureId>> get requiredConfiguration =>
      const CollectSetupConfigurationFieldsUseCase()(
        selected,
        enabledOptions: state.enabledOptions,
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
      state.configured.contains(module) && configurationComplete(module);
  SetupModule? get incompleteRequiredConfigurationModule {
    for (final field in requiredConfiguration.keys) {
      if (!moduleReady(field.module)) return field.module;
    }
    return null;
  }

  List<SetupModule> get modules => [
    if (requirements.containsKey(SetupRequirement.familyPairing))
      SetupModule.family,
    if (requirements.containsKey(SetupRequirement.aiConfiguration))
      SetupModule.ai,
    ...selected
        .map((feature) => feature.configurationModule)
        .whereType<SetupModule>()
        .toSet(),
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
    notifyListeners();
  }

  void setMode(SetupDeviceMode mode) {
    if (state.mode == mode) return;
    state.mode = mode;
    state.moduleIndex = 0;
    pairingSession++;
    unawaited(familySubscription?.cancel());
    familySubscription = null;
    state.signedIn = false;
    state.paired = false;
    state.pairingInvitation = null;
    state.familyMembers = const [];
    state.generatingInvitation = false;
    state.invitationFailed = false;
    state.familyMembersFailed = false;
    state.disconnectingMembers.clear();
    state.disconnectFailed = false;
    state.configured.remove(SetupModule.family);
    changed();
  }

  void select(SetupFeatureId id, bool enabled) {
    if (available.any((feature) => feature.id == id && feature.alwaysEnabled)) {
      return;
    }
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
    state.config = config;
    state.configured.remove(SetupModule.nightscout);
    state.moduleIndex = 0;
    changed();
  }

  void setNightscout(String url, String token) {
    state.nightscoutUrl = url;
    state.nightscoutToken = token;
    state.configured.remove(SetupModule.nightscout);
    changed();
  }

  void goTo(int step) {
    state.step = step.clamp(0, 5);
    changed();
  }

  void back() {
    if (state.step == 5) {
      state.step = 4;
      state.moduleIndex = modules.isEmpty ? 0 : modules.length - 1;
    } else if (state.step == 4 && state.moduleIndex > 0) {
      state.moduleIndex--;
    } else if (state.step > 0) {
      state.step--;
    }
    changed();
  }

  bool next() {
    if (state.step == 4 && module != null && !moduleReady(module!)) {
      return false;
    }
    if (state.step == 4 && state.moduleIndex + 1 < modules.length) {
      state.moduleIndex++;
    } else if (state.step < 5) {
      state.step++;
    }
    changed();
    return true;
  }

  void grant(SetupRequirement requirement) {
    state.granted.add(requirement);
    changed();
  }

  void simulateSignIn() {
    if (state.signedIn || disposed) return;
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

  void simulateModule(SetupModule module) {
    if (!configurationComplete(module)) return;
    state.configured.add(module);
    changed();
  }

  void skipModule() {
    final current = module;
    if (current == null) return;
    switch (current) {
      case SetupModule.family:
        state.selected.removeAll({
          SetupFeatureId.familyChat,
          SetupFeatureId.childOverview,
        });
        state.shareData = false;
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
      state.step = 5;
      state.moduleIndex = 0;
    }
    changed();
  }
}
