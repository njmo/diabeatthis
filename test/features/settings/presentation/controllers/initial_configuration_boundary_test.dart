import 'dart:async';

import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
import 'package:diabeatthis/features/settings/data/settings_storage_keys.dart';
import 'package:diabeatthis/features/settings/presentation/controllers/initial_configuration_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/regression/scripted_initial_configuration_use_case.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const local = DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  );
  test(
    'configuration submits the captured normalized draft only once',
    () async {
      SharedPreferences.setMockInitialValues({
        nightscoutUrlKey: 'old-url',
        nightscoutTokenKey: 'old-token',
        childNameKey: 'Old',
      });
      final prefs = await SharedPreferences.getInstance();
      final pending = Completer<void>();
      final writes = ScriptedRead<void>('apply configuration', [
        (
          arguments: [local, 'https://example.test', 'token', 'New', 'en'],
          respond: () => pending.future,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          dataSourceConfigProvider.overrideWith((ref) async => local),
          applyInitialConfigurationUseCaseProvider.overrideWithValue(
            ScriptedInitialConfigurationUseCase(writes),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        initialConfigurationControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final initial = await container.read(
        initialConfigurationControllerProvider.future,
      );
      expect(initial.userName, 'Old');
      expect(initial.nightscoutUrl, 'old-url');
      final controller = container.read(
        initialConfigurationControllerProvider.notifier,
      );
      controller.setUserName(' New ');
      controller.setLanguage(applicationLanguageByCode('en'));
      controller.setNightscoutUrl(' https://example.test ');
      controller.setNightscoutToken(' token ');
      final result = controller.submit();
      expect(await controller.submit(), false);
      expect(
        container.read(initialConfigurationControllerProvider).value!.isSaving,
        true,
      );
      pending.complete();
      expect(await result, true);
      writes.verifyComplete();
    },
  );

  test(
    'failed submission preserves editable fields and allows recovery',
    () async {
      SharedPreferences.setMockInitialValues({childNameKey: 'Child'});
      final prefs = await SharedPreferences.getInstance();
      final writes = ScriptedRead<void>('apply configuration', [
        (
          arguments: [local, '', '', 'Child', 'pl'],
          respond: () => throw StateError('Mocked save error'),
        ),
        (arguments: [local, 'retry', '', 'Child', 'pl'], respond: () {}),
      ]);
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          dataSourceConfigProvider.overrideWith((ref) async => local),
          applyInitialConfigurationUseCaseProvider.overrideWithValue(
            ScriptedInitialConfigurationUseCase(writes),
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
      expect(await controller.submit(), false);
      expect(
        container.read(initialConfigurationControllerProvider).value!.isSaving,
        false,
      );
      expect(
        container
            .read(initialConfigurationControllerProvider)
            .value!
            .submitError,
        isNotEmpty,
      );
      controller.setNightscoutUrl('retry');
      expect(
        container
            .read(initialConfigurationControllerProvider)
            .value!
            .submitError,
        isNull,
      );
      expect(await controller.submit(), true);
      writes.verifyComplete();
    },
  );
}
