import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../../app/providers/foreground_task_state_provider.dart';
import '../../../../common/events/data/app/dump_logs_event.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/events/data/app/sync_data_key.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/nightscout/nightscout_cloud_connection_tester.dart';
import '../../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import '../../../../core/data_sources/nightscout/providers/nightscout_url_provider.dart';
import '../../../../core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import '../../../../core/logger/logger.dart';
import '../widgets/data_source_settings_section.dart';
import '../widgets/database_settings_section.dart';
import '../widgets/meal_advisor_settings_section.dart';
import '../widgets/nightscout_connection_fields.dart';
import '../widgets/settings_section_card.dart';

const _childNameKey = 'main-user-name';

@RoutePage()
class SettingsPage extends HookConsumerWidget with Logging {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPrefsProvider);

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final urlController = useTextEditingController();
    final tokenController = useTextEditingController();
    final childNameController = useTextEditingController();

    final initialized = useState(false);
    final isSaving = useState(false);
    final submitError = useState<String?>(null);
    final selectedDataSourceConfig = useState<DataSourceConfig?>(null);

    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Błąd: $e'))),
      data: (prefs) {
        final dataSourceConfigAsync = ref.watch(dataSourceConfigProvider);
        final visibleDataSourceConfig =
            selectedDataSourceConfig.value ??
            dataSourceConfigAsync.maybeWhen(
              data: (config) => config,
              orElse: () => null,
            );

        if (!initialized.value) {
          urlController.text = prefs.getString(nightscoutUrlKey) ?? '';
          tokenController.text = prefs.getString(nightscoutTokenKey) ?? '';
          childNameController.text = prefs.getString(_childNameKey) ?? '';
          initialized.value = true;
        }

        Future<void> handleSave() async {
          FocusScope.of(context).unfocus();
          submitError.value = null;

          final isValid = formKey.currentState?.validate() ?? false;
          if (!isValid) return;

          final newUrl = urlController.text.trim();
          logI('newUrl: $newUrl');
          final newToken = tokenController.text.trim();
          final newChildName = childNameController.text.trim();

          final oldUrl = prefs.getString(nightscoutUrlKey)?.trim() ?? '';
          logI('oldUrl: $oldUrl');
          final oldToken = prefs.getString(nightscoutTokenKey)?.trim() ?? '';
          final oldChildName = prefs.getString(_childNameKey)?.trim() ?? '';

          final urlChanged = newUrl != oldUrl;
          final tokenChanged = newToken != oldToken;
          final childNameChanged = newChildName != oldChildName;
          final nightscoutConnectionChanged = urlChanged || tokenChanged;

          isSaving.value = true;

          try {
            if (nightscoutConnectionChanged) {
              final repo = NightscoutRepositoryImpl(
                nightscoutUrl: newUrl,
                nightscoutToken: newToken,
              );
              final selectedConfig = selectedDataSourceConfig.value;
              final DataSourceConfig config;
              if (selectedConfig != null) {
                config = selectedConfig;
              } else {
                config = await ref.read(dataSourceConfigProvider.future);
              }
              await _validateNightscoutConnection(repo, config);
            }

            if (urlChanged) {
              await prefs.setString(nightscoutUrlKey, newUrl);
            }

            if (tokenChanged) {
              await prefs.setString(nightscoutTokenKey, newToken);
            }

            if (childNameChanged) {
              await prefs.setString(_childNameKey, newChildName);
            }

            if (nightscoutConnectionChanged || childNameChanged) {
              ref.invalidate(sharedPrefsProvider);
              ref.invalidate(nightscoutRepositoryProvider);
              ref.invalidate(nightscoutUrlProvider);
              ref.invalidate(nightscoutTokenProvider);
            }

            if (nightscoutConnectionChanged) {
              final foregroundBridge = ref.read(appForegroundBridgeProvider);
              final taskState = ref.read(foregroundTaskStateProvider.notifier);

              Future<void> startOrRestartForeground() async {
                if (oldUrl.isEmpty) {
                  logI("starting service");
                  await foregroundBridge.startMonitoring();
                } else {
                  logI("restarting service");
                  await foregroundBridge.restartService();
                }
              }

              try {
                await startOrRestartForeground();
                await taskState.waitForStartupMessage();
              } catch (e, st) {
                logW('Foreground alive wait timed out: $e\n$st');
              }

              ref
                  .read(appEventRouterProvider)
                  .send(
                    const ExecuteCommandEvent.syncData(
                      data: SyncDataKey.dashboardStartup,
                    ),
                  );
            }

            if (context.mounted) {
              context.router.replace(NamedRoute('DashboardRoute'));
            }
          } catch (e, st) {
            logE('Błąd podczas zapisu ustawień Nightscout $e, $st');
            submitError.value =
                'Problem z połączeniem. Sprawdź adres Nightscout.';
          } finally {
            isSaving.value = false;
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Ustawienia')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DataSourceSettingsSection(
                      onChanged: (config) {
                        selectedDataSourceConfig.value = config;
                      },
                    ),
                    if (visibleDataSourceConfig != null &&
                        _usesNightscout(visibleDataSourceConfig)) ...[
                      const SizedBox(height: 16),
                      SettingsSectionCard(
                        icon: Icons.cloud_outlined,
                        title: 'Nightscout',
                        subtitle:
                            'Podaj adres swojego Nightscout. Bez niego nie możemy pobrać danych.',
                        children: [
                          NightscoutConnectionFields(
                            urlController: urlController,
                            tokenController: tokenController,
                            onChanged: (_) {
                              if (submitError.value != null) {
                                submitError.value = null;
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: childNameController,
                            decoration: const InputDecoration(
                              labelText: 'Imię dziecka',
                              hintText: 'Oliwier',
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          if (submitError.value != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              submitError.value!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: isSaving.value ? null : handleSave,
                            icon: isSaving.value
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: const Text('Zapisz i przejdź dalej'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      icon: Icons.receipt_long_outlined,
                      title: 'Logi',
                      subtitle: 'Zbierz pliki diagnostyczne z UI lub tła.',
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () async {
                                final nowString = clock.now().toIso8601String();
                                final fileName = 'logs-$nowString-ui.txt';
                                final file = await LogFileWriter.writeLogs(
                                  Log.bufferedLogs,
                                  fileName,
                                );
                                await SharePlus.instance.share(
                                  ShareParams(files: [XFile(file.path)]),
                                );
                              },
                              icon: const Icon(Icons.ios_share_outlined),
                              label: const Text('Logi z UI'),
                            ),
                            FilledButton.icon(
                              onPressed: () {
                                final nowString = clock.now().toIso8601String();
                                final fileName = 'logs-$nowString-fg.txt';
                                final payload = DumpLogsEvent.saveToFile(
                                  name: fileName,
                                );
                                ref.read(appEventRouterProvider).send(payload);
                              },
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Logi z tła'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const MealAdvisorSettingsSection(),
                    const SizedBox(height: 16),
                    const DatabaseSettingsSection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _usesNightscout(DataSourceConfig config) {
    return config.bgSource == BgSource.cloud ||
        config.treatmentsSource == TreatmentsSource.cloud ||
        config.pumpStatusSource == PumpStatusSource.cloud ||
        config.historySource == HistorySource.cloud;
  }

  Future<void> _validateNightscoutConnection(
    NightscoutRepositoryImpl repository,
    DataSourceConfig config,
  ) async {
    if (!_usesNightscout(config)) return;
    await NightscoutCloudConnectionTester(repository).testConnection();
  }
}
