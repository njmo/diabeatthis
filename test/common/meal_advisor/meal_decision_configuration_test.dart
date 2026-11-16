import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SetupWizardController decisionSetupController() => SetupWizardController(
  SetupWizardState(
    config: const DataSourceConfig.defaults(),
    language: applicationLanguageByCode('en'),
    name: 'Child',
    nightscoutUrl: '',
    nightscoutToken: '',
  ),
);

void main() {
  test('advisor is mandatory and follows family before AI', () {
    final controller = decisionSetupController();
    addTearDown(controller.dispose);
    expect(
      controller.selected.any((f) => f.id == SetupFeatureId.mealAdvisor),
      isTrue,
    );
    controller.select(SetupFeatureId.mealAdvisor, false);
    expect(
      controller.selected.any((f) => f.id == SetupFeatureId.mealAdvisor),
      isTrue,
    );
    expect(
      controller.modules.indexOf(SetupModule.mealAdvisor),
      greaterThan(controller.modules.indexOf(SetupModule.family)),
    );
    expect(
      controller.modules.indexOf(SetupModule.mealAdvisor),
      lessThan(controller.modules.indexOf(SetupModule.ai)),
    );
    expect(controller.modules.first, SetupModule.data);
    expect(controller.modules.last, SetupModule.ai);
    expect(
      controller.state.mealDecisionPreferences.method,
      MealDecisionMethod.app,
    );
  });
  test(
    'caregiver method requires signed in, paired family and cannot bypass AI lock',
    () {
      final controller = decisionSetupController();
      addTearDown(controller.dispose);
      controller.setNightscout('https://example.com', 'token');
      controller.simulateModule(SetupModule.nightscout);
      controller.selectMealDecisionMethod(MealDecisionMethod.ai);
      controller.selectMealDecisionMethod(MealDecisionMethod.caregiver);
      expect(
        controller.state.mealDecisionPreferences.method,
        MealDecisionMethod.app,
      );
      controller.state.signedIn = true;
      controller.state.paired = true;
      controller.selectMealDecisionMethod(MealDecisionMethod.caregiver);
      expect(
        controller.state.mealDecisionPreferences.method,
        MealDecisionMethod.caregiver,
      );
      controller.state.paired = false;
      expect(controller.moduleReady(SetupModule.mealAdvisor), isFalse);
      expect(
        controller.incompleteRequiredConfigurationModule,
        SetupModule.mealAdvisor,
      );
      controller.state.step = SetupStep.configuration.index;
      controller.state.moduleIndex = controller.modules.indexOf(
        SetupModule.mealAdvisor,
      );
      expect(controller.next(), isFalse);
      controller.selectMealDecisionMethod(MealDecisionMethod.app);
      expect(controller.next(), isTrue);
    },
  );
  test(
    'caregiver response feature is configurable and family skipping removes it',
    () {
      final controller = decisionSetupController();
      addTearDown(controller.dispose);
      controller.setMode(SetupDeviceMode.caregiver);
      expect(
        controller.selected.any(
          (f) => f.id == SetupFeatureId.caregiverMealDecisions,
        ),
        isTrue,
      );
      controller.setCaregiverResponses(false);
      expect(
        controller.state.mealDecisionPreferences.caregiverResponsesEnabled,
        isFalse,
      );
      controller.state.moduleIndex = controller.modules.indexOf(
        SetupModule.family,
      );
      controller.skipModule();
      expect(
        controller.selected.any(
          (f) => f.id == SetupFeatureId.caregiverMealDecisions,
        ),
        isFalse,
      );
      expect(controller.modules, isNot(contains(SetupModule.mealAdvisor)));
    },
  );
  test(
    'preferences round trip, reject malformed values and refuse AI writes',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);
      await container.read(sharedPrefsProvider.future);
      expect(
        container.read(mealDecisionPreferencesProvider).method,
        MealDecisionMethod.app,
      );
      const selection = MealDecisionPreferences(
        method: MealDecisionMethod.caregiver,
        caregiverResponsesEnabled: false,
      );
      await container.read(saveMealDecisionPreferencesProvider)(selection);
      final read = container.read(mealDecisionPreferencesProvider);
      expect(read.method, MealDecisionMethod.caregiver);
      expect(read.caregiverResponsesEnabled, isFalse);
      await expectLater(
        container.read(saveMealDecisionPreferencesProvider)(
          const MealDecisionPreferences(method: MealDecisionMethod.ai),
        ),
        throwsStateError,
      );
      expect(
        MealDecisionPreferences.decode(
          prefs.getString(mealDecisionPreferencesKey),
        ).method,
        MealDecisionMethod.caregiver,
      );
      expect(
        MealDecisionPreferences.decode('broken').method,
        MealDecisionMethod.app,
      );
      expect(
        MealDecisionPreferences.decode('{"method":"unknown"}').method,
        MealDecisionMethod.app,
      );
    },
  );
  test(
    'existing AI opt-in remains visible and choosing App supersedes it',
    () async {
      SharedPreferences.setMockInitialValues({
        aiAssistedMealAdvisorPreferenceKey: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          aiAssistedMealAdvisorAvailableProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);
      await container.read(sharedPrefsProvider.future);
      expect(
        container.read(mealDecisionPreferencesProvider).method,
        MealDecisionMethod.ai,
      );
      expect(container.read(aiAssistedMealAdvisorEnabledProvider), isTrue);
      await container.read(saveMealDecisionPreferencesProvider)(
        const MealDecisionPreferences(),
      );
      expect(container.read(aiAssistedMealAdvisorEnabledProvider), isFalse);
      await container
          .read(aiAssistedMealAdvisorSettingsControllerProvider)
          .save(true);
      expect(
        container.read(mealDecisionPreferencesProvider).method,
        MealDecisionMethod.ai,
      );
      await container
          .read(aiAssistedMealAdvisorSettingsControllerProvider)
          .save(false);
      expect(
        container.read(mealDecisionPreferencesProvider).method,
        MealDecisionMethod.app,
      );
    },
  );
  test(
    'failed setup restores missing or previous preferences and retry saves opt out',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWith((ref) async => prefs)],
      );
      addTearDown(container.dispose);
      await container.read(sharedPrefsProvider.future);
      final configure = container.read(
        configureMealDecisionPreferencesProvider,
      );
      const desired = MealDecisionPreferences(
        method: MealDecisionMethod.caregiver,
      );
      await expectLater(
        configure(desired, () async {
          throw StateError('setup failed');
        }),
        throwsStateError,
      );
      expect(prefs.containsKey(mealDecisionPreferencesKey), isFalse);
      await container.read(saveMealDecisionPreferencesProvider)(desired);
      await expectLater(
        configure(const MealDecisionPreferences(), () async {
          throw StateError('setup failed');
        }),
        throwsStateError,
      );
      expect(
        container.read(mealDecisionPreferencesProvider).method,
        MealDecisionMethod.caregiver,
      );
      await configure(
        const MealDecisionPreferences(caregiverResponsesEnabled: false),
        () async {},
      );
      expect(
        container
            .read(mealDecisionPreferencesProvider)
            .caregiverResponsesEnabled,
        isFalse,
      );
    },
  );
}
