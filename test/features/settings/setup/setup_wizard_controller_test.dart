import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SetupWizardController controller;
  setUp(() {
    controller = SetupWizardController(
      SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('pl'),
        name: 'Child',
        nightscoutUrl: '',
        nightscoutToken: '',
      ),
    );
    addTearDown(controller.dispose);
  });

  test(
    'feature modules stay within step five and back restores the preceding module',
    () {
      controller.goTo(4);
      expect(controller.modules, [
        SetupModule.family,
        SetupModule.ai,
        SetupModule.activity,
        SetupModule.lowTreatment,
        SetupModule.nightscout,
      ]);
      expect(controller.next(), isFalse);
      controller.simulateSignIn();
      controller.simulatePairing();
      expect(controller.next(), isTrue);
      expect(controller.state.step, 4);
      expect(controller.module, SetupModule.ai);
      controller.back();
      expect(controller.module, SetupModule.family);
      expect(controller.state.paired, isTrue);
      controller.next();
      controller.simulateModule(SetupModule.ai);
      controller.next();
      controller.simulateModule(SetupModule.activity);
      controller.next();
      controller.simulateModule(SetupModule.lowTreatment);
      controller.next();
      controller.simulateModule(SetupModule.nightscout);
      controller.next();
      expect(controller.state.step, 5);
      controller.back();
      expect(controller.module, SetupModule.nightscout);
      expect(controller.state.step, 4);
    },
  );

  test(
    'skipping AI deselects dependent features and continues at the next module',
    () {
      controller.goTo(4);
      controller.simulateSignIn();
      controller.simulatePairing();
      controller.next();
      controller.skipModule();
      expect(
        controller.state.selected,
        isNot(contains(SetupFeatureId.mealPhoto)),
      );
      expect(
        controller.state.selected,
        isNot(contains(SetupFeatureId.aiAssistance)),
      );
      expect(controller.module, SetupModule.activity);
      expect(controller.state.step, 4);
    },
  );

  test(
    'patient source requirements cannot be bypassed by skipping Nightscout',
    () {
      controller.goTo(4);
      controller.skipModule();
      controller.skipModule();
      controller.skipModule();
      expect(controller.module, SetupModule.lowTreatment);
      controller.simulateModule(SetupModule.lowTreatment);
      controller.next();
      expect(controller.module, SetupModule.nightscout);
      controller.skipModule();
      expect(controller.module, SetupModule.nightscout);
      expect(controller.state.config.usesCloud, isTrue);
    },
  );

  test(
    'mode changes clear simulated pairing and preserve separate feature selections',
    () {
      controller.select(SetupFeatureId.mealPhoto, false);
      controller.simulateSignIn();
      controller.simulatePairing();
      controller.setMode(SetupDeviceMode.caregiver);
      expect(controller.state.paired, isFalse);
      expect(
        controller.requirements.containsKey(
          SetupRequirement.backgroundExecution,
        ),
        isFalse,
      );
      expect(controller.modules, [SetupModule.family]);
      controller.select(SetupFeatureId.childOverview, false);
      controller.setMode(SetupDeviceMode.patient);
      expect(
        controller.state.selected.contains(SetupFeatureId.mealPhoto),
        isFalse,
      );
      controller.setMode(SetupDeviceMode.caregiver);
      expect(
        controller.state.selected.contains(SetupFeatureId.childOverview),
        isFalse,
      );
    },
  );

  test('editing credentials invalidates the simulated connection check', () {
    controller.simulateModule(SetupModule.nightscout);
    controller.setNightscout('https://new.example', 'token');
    expect(
      controller.state.configured.contains(SetupModule.nightscout),
      isFalse,
    );
    expect(controller.state.nightscoutUrl, 'https://new.example');
  });
}
