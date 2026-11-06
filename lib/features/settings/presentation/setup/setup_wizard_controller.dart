import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../common/family/demo_family_pairing_repository.dart';
import '../../../../common/family/family_pairing_member.dart';
import '../../../../common/family/family_pairing_repository.dart';

import '../../../../common/setup/domain/collect_setup_requirements_use_case.dart';
import '../../../../common/setup/domain/get_available_setup_features_use_case.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import 'setup_wizard_state.dart';

/// Session-only demo choices. Never starts services or writes preferences.
class SetupWizardController extends ChangeNotifier {
  SetupWizardController(this.state, {FamilyPairingRepository? familyRepository})
    : familyRepository = familyRepository ?? DemoFamilyPairingRepository(),
      ownsFamilyRepository = familyRepository == null;
  final FamilyPairingRepository familyRepository;
  final bool ownsFamilyRepository;
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
      final invitation = await familyRepository.createInvitation(mode);
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
      .where((feature) => state.selected.contains(feature.id))
      .toList();
  Map<SetupRequirement, Set<SetupFeatureId>> get requirements =>
      const CollectSetupRequirementsUseCase()(selected);
  List<SetupModule> get modules => [
    if (requirements.containsKey(SetupRequirement.familyPairing))
      SetupModule.family,
    if (requirements.containsKey(SetupRequirement.aiConfiguration))
      SetupModule.ai,
    if (state.mode == SetupDeviceMode.patient && state.config.usesCloud)
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
    state.configured.remove(SetupModule.family);
    changed();
  }

  void select(SetupFeatureId id, bool enabled) {
    if (enabled) {
      state.selected.add(id);
    } else {
      state.selected.remove(id);
    }
    state.moduleIndex = 0;
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
    if (state.step == 4 &&
        module != null &&
        !state.configured.contains(module)) {
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
      familySubscription = familyRepository
          .watchMembers(state.mode)
          .listen(
            (members) {
              if (disposed ||
                  session != pairingSession ||
                  request != membershipRequest) {
                return;
              }
              state.familyMembers = List.unmodifiable(members);
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
    final repository = familyRepository;
    if (repository is DemoFamilyPairingRepository) {
      repository.simulatePairing(state.mode);
    }
  }

  void simulateModule(SetupModule module) {
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
      case SetupModule.nightscout:
        return; // Real patient sources cannot be silently rewritten.
    }
    if (state.moduleIndex >= modules.length) {
      state.step = 5;
      state.moduleIndex = 0;
    }
    changed();
  }
}
