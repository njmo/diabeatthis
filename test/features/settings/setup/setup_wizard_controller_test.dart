import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature_option.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/setup_live_services.dart';

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
    'feature modules stay within configuration and back restores the preceding module',
    () async {
      controller.goTo(SetupStep.configuration.index);
      expect(controller.modules, [
        SetupModule.data,
        SetupModule.nightscout,
        SetupModule.family,
        SetupModule.activity,
        SetupModule.lowTreatment,
        SetupModule.mealAdvisor,
        SetupModule.ai,
      ]);
      expect(controller.module, SetupModule.data);
      expect(await controller.validateAndNext(), isTrue);
      expect(controller.module, SetupModule.nightscout);
      controller.setNightscout('https://example.com', '');
      expect(await controller.validateAndNext(), isTrue);
      expect(controller.module, SetupModule.family);
      expect(controller.next(), isFalse);
      controller.simulateSignIn();
      controller.simulatePairing();
      expect(controller.next(), isTrue);
      expect(controller.state.step, SetupStep.configuration.index);
      expect(controller.module, SetupModule.activity);
      controller.next();
      expect(controller.module, SetupModule.lowTreatment);
      controller.next();
      expect(controller.module, SetupModule.mealAdvisor);
      controller.next();
      expect(controller.module, SetupModule.ai);
      controller.back();
      expect(controller.module, SetupModule.mealAdvisor);
      controller.back();
      expect(controller.module, SetupModule.lowTreatment);
      expect(controller.state.paired, isTrue);
      controller.next();
      controller.next();
      controller.simulateModule(SetupModule.ai);
      expect(await controller.validateAndNext(), isTrue);
      expect(controller.state.step, SetupStep.summary.index);
      controller.back();
      expect(controller.module, SetupModule.ai);
      expect(controller.state.step, SetupStep.configuration.index);
    },
  );
  test(
    'skipping the final AI module deselects dependent features and opens summary',
    () {
      controller.goTo(SetupStep.configuration.index);
      controller.state.moduleIndex = controller.modules.indexOf(SetupModule.ai);
      controller.skipModule();
      expect(
        controller.state.selected,
        isNot(contains(SetupFeatureId.mealPhoto)),
      );
      expect(
        controller.state.selected,
        isNot(contains(SetupFeatureId.aiAssistance)),
      );
      expect(controller.state.step, SetupStep.summary.index);
    },
  );
  test(
    'patient source requirements cannot be bypassed by skipping Nightscout',
    () {
      controller.goTo(SetupStep.configuration.index);
      controller.state.moduleIndex = controller.modules.indexOf(
        SetupModule.nightscout,
      );
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
      controller.simulateModule(SetupModule.nightscout);
      controller.setMode(SetupDeviceMode.caregiver);
      expect(
        controller.state.configured,
        isNot(contains(SetupModule.nightscout)),
      );
      expect(controller.state.paired, isFalse);
      expect(
        controller.requirements.containsKey(
          SetupRequirement.backgroundExecution,
        ),
        isFalse,
      );
      expect(controller.modules, [
        SetupModule.nightscout,
        SetupModule.family,
        SetupModule.mealAdvisor,
        SetupModule.ai,
      ]);
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

  const localConfig = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );

  test('source changes preserve the current module when Nightscout moves', () {
    controller.state.moduleIndex = controller.modules.indexOf(SetupModule.data);
    controller.setConfig(localConfig);
    expect(controller.module, SetupModule.data);
    expect(controller.modules, isNot(contains(SetupModule.nightscout)));
    controller.setConfig(const DataSourceConfig.defaults());
    expect(controller.module, SetupModule.data);
    expect(controller.modules.take(2), [
      SetupModule.data,
      SetupModule.nightscout,
    ]);
    expect(controller.modules.toSet().length, controller.modules.length);
  });

  test(
    'new upload requirement invalidates a checked read-only connection',
    () async {
      controller.setNightscout('https://example.com', 'token');
      controller.simulateModule(SetupModule.nightscout);
      controller.state.moduleIndex = controller.modules.indexOf(
        SetupModule.lowTreatment,
      );
      controller.selectOption(
        SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        true,
      );
      expect(controller.module, SetupModule.lowTreatment);
      expect(
        controller.state.configured,
        isNot(contains(SetupModule.nightscout)),
      );
      expect(
        controller.incompleteRequiredConfigurationModule,
        SetupModule.nightscout,
      );
      controller.goTo(SetupStep.configuration.index);
      expect(await controller.validateAndNext(), isFalse);
      expect(controller.module, SetupModule.nightscout);
      expect(await controller.validateAndNext(), isTrue);
      expect(controller.module, SetupModule.family);
    },
  );

  test(
    'options preserve the module when Nightscout is inserted and removed',
    () {
      controller.setConfig(localConfig);
      controller.state.moduleIndex = controller.modules.indexOf(
        SetupModule.lowTreatment,
      );
      controller.selectOption(
        SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        true,
      );
      expect(controller.module, SetupModule.lowTreatment);
      expect(controller.modules.take(2), [
        SetupModule.data,
        SetupModule.nightscout,
      ]);
      controller.selectOption(
        SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        false,
      );
      expect(controller.module, SetupModule.lowTreatment);
      expect(controller.modules, isNot(contains(SetupModule.nightscout)));
    },
  );

  test('editing credentials invalidates the simulated connection check', () {
    controller.setNightscout('https://old.example.com', '');
    controller.simulateModule(SetupModule.nightscout);
    controller.setNightscout('https://new.example', 'token');
    expect(
      controller.state.configured.contains(SetupModule.nightscout),
      isFalse,
    );
    expect(controller.state.nightscoutUrl, 'https://new.example');
  });

  test(
    'applying null Google account switches caregiver to patient and removes nightscout configured status',
    () {
      final auth = SetupGoogleAuthenticationTestRepository();
      addTearDown(auth.dispose);
      final testController = SetupWizardController(
        SetupWizardState(
          config: const DataSourceConfig.defaults(),
          language: applicationLanguageByCode('pl'),
          name: 'Child',
          nightscoutUrl: 'https://caregiver.test',
          nightscoutToken: '',
        ),
        authentication: auth,
      );
      addTearDown(testController.dispose);

      testController.applyGoogleAccount(
        const GoogleAccount(uid: 'caregiver-1', displayName: 'Parent'),
      );
      testController.setMode(SetupDeviceMode.caregiver);
      expect(testController.state.mode, SetupDeviceMode.caregiver);
      testController.simulateModule(SetupModule.nightscout);
      expect(
        testController.state.configured.contains(SetupModule.nightscout),
        isTrue,
      );

      testController.applyGoogleAccount(null);

      expect(testController.state.mode, SetupDeviceMode.patient);
      expect(
        testController.state.configured.contains(SetupModule.nightscout),
        isFalse,
      );
    },
  );
}
