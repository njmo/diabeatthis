import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/external_app_installation_checker.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/settings/application/apply_initial_configuration_use_case.dart';
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
  const cloud = DataSourceConfig.defaults();
  for (final kind in [
    'local-storage',
    'cloud-connection',
    'missing-aaps',
    'missing-xdrip',
  ]) {
    test(
      'initial configuration reports $kind accurately and preserves the editable draft',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final config = kind == 'cloud-connection' ? cloud : local;
        final error = switch (kind) {
          'missing-aaps' => DataSourceConfigUnavailableException({
            ExternalDataApp.aaps,
          }),
          'missing-xdrip' => DataSourceConfigUnavailableException({
            ExternalDataApp.xdrip,
          }),
          _ => StateError('Unavailable'),
        };
        final writes = ScriptedRead<void>('apply', [
          (
            arguments: [config, 'https://example.test', 'token', 'Child', 'pl'],
            respond: () => throw error,
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWith(
              (ref) => throw StateError(
                'Controller must not read the database directly',
              ),
            ),
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            dataSourceConfigProvider.overrideWith((ref) async => config),
            applyInitialConfigurationUseCaseProvider.overrideWithValue(
              ScriptedInitialConfigurationUseCase(writes),
            ),
          ],
        );
        addTearDown(container.dispose);
        final provider = initialConfigurationControllerProvider;
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        await container.read(provider.future);
        final controller = container.read(provider.notifier);
        controller.setDataSourceConfig(config);
        controller.setUserName(' Child ');
        controller.setNightscoutUrl(' https://example.test ');
        controller.setNightscoutToken(' token ');
        expect(await controller.submit(), false);
        final state = container.read(provider).requireValue;
        expect(state.isSaving, false);
        expect(state.config, config);
        expect(state.userName, ' Child ');
        expect(state.nightscoutUrl, ' https://example.test ');
        expect(state.nightscoutToken, ' token ');
        expect(state.submitError, switch (kind) {
          'missing-aaps' => lang.settingsMissingAppsSaveError('AAPS'),
          'missing-xdrip' => lang.settingsMissingAppsSaveError('xDrip+'),
          'cloud-connection' => lang.settingsConnectionError,
          _ => lang.settingsInitialSaveError,
        });
        controller.setDataSourceConfig(config == local ? cloud : local);
        expect(container.read(provider).requireValue.submitError, isNull);
        expect(prefs.getKeys(), isEmpty);
        writes.verifyComplete();
      },
    );
  }
}
