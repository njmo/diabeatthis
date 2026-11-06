import 'package:flutter/foundation.dart';

import '../../../../common/setup/domain/collect_setup_requirements_use_case.dart';
import '../../../../common/setup/domain/get_available_setup_features_use_case.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import 'setup_wizard_state.dart';

/// Session-only demo choices. Never starts services or writes preferences.
class SetupWizardController extends ChangeNotifier {
  SetupWizardController(this.state);
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
    state.signedIn = false;
    state.paired = false;
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
    state.signedIn = true;
    changed();
  }

  void simulatePairing() {
    if (!state.signedIn) return;
    state.paired = true;
    state.configured.add(SetupModule.family);
    changed();
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
