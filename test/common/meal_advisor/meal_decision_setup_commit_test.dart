import 'package:diabeatthis/common/family_sync/enable_initial_family_sharing.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/presentation/controllers/initial_configuration_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/regression/scripted_initial_configuration_use_case.dart';
import '../../helpers/regression/scripted_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'post-completion cleanup failure cannot roll back the saved advisor choice',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      const config = DataSourceConfig(
        bgSource: BgSource.aaps,
        treatmentsSource: TreatmentsSource.aaps,
        pumpStatusSource: PumpStatusSource.aaps,
        historySource: HistorySource.local,
        mirrorToLocal: false,
      );
      var cleanup = 0;
      final writes = ScriptedRead<void>('configuration', [
        (
          arguments: [config, '', '', 'Child', 'en'],
          respond: () async {
            await prefs.setBool(initialConfigurationDoneKey, true);
          },
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          dataSourceConfigProvider.overrideWith((ref) async => config),
          applyInitialConfigurationUseCaseProvider.overrideWithValue(
            ScriptedInitialConfigurationUseCase(writes),
          ),
          reconcileInitialFamilySharingProvider.overrideWith(
            (ref) => (selected) async {
              if (++cleanup == 2) throw StateError('cleanup unavailable');
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        initialConfigurationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(initialConfigurationControllerProvider.future);
      final controller = container.read(
        initialConfigurationControllerProvider.notifier,
      );
      controller.setUserName('Child');
      controller.setLanguage(applicationLanguageByCode('en'));
      final saved = await controller.submit(
        mealDecisionPreferences: const MealDecisionPreferences(
          caregiverResponsesEnabled: false,
        ),
      );
      expect(saved, isTrue);
      expect(prefs.getBool(initialConfigurationDoneKey), isTrue);
      expect(
        MealDecisionPreferences.decode(
          prefs.getString(mealDecisionPreferencesKey),
        ).caregiverResponsesEnabled,
        isFalse,
      );
      writes.verifyComplete();
    },
  );
}
