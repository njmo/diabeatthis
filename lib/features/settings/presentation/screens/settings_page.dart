import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../common/events/data/app/dump_logs_event.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../common/l10n/application_language.dart';
import '../../../../common/l10n/application_language_storage_keys.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../../core/data_sources/nightscout/nightscout_storage_keys.dart';
import '../../../../core/logger/logger.dart';
import '../../data/models/nightscout_settings_draft.dart';
import '../../data/settings_storage_keys.dart';
import '../controllers/nightscout_settings_controller.dart';
import '../widgets/application_language_selector.dart';
import '../widgets/application_theme_settings_section.dart';
import '../widgets/data_source_settings_section.dart';
import '../widgets/database_settings_section.dart';
import '../widgets/meal_advisor_settings_section.dart';
import '../widgets/nightscout_settings_section.dart';
import '../widgets/settings_section_card.dart';

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

    final tempTargetsEnabled = useState(false);
    useListenable(tokenController);
    final initialized = useState(false);
    final saveState = ref.watch(nightscoutSettingsControllerProvider);
    final selectedDataSourceConfig = useState<DataSourceConfig?>(null);

    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text(context.lang.settingsGenericError(e))),
      ),
      data: (prefs) {
        final dataSourceConfigAsync = ref.watch(dataSourceConfigProvider);
        final languageAsync = ref.watch(applicationLanguageControllerProvider);
        final visibleDataSourceConfig =
            selectedDataSourceConfig.value ??
            dataSourceConfigAsync.maybeWhen(
              data: (config) => config,
              orElse: () => null,
            );

        if (!initialized.value) {
          final pendingDraft = saveState.pendingDraft;
          urlController.text =
              pendingDraft?.url ?? prefs.getString(nightscoutUrlKey) ?? '';
          tokenController.text =
              pendingDraft?.token ?? prefs.getString(nightscoutTokenKey) ?? '';
          tempTargetsEnabled.value =
              (pendingDraft?.tempTargetsEnabled ??
                  prefs.getBool(nightscoutTempTargetsEnabledKey) == true) &&
              tokenController.text.trim().isNotEmpty;
          childNameController.text =
              pendingDraft?.childName ?? prefs.getString(childNameKey) ?? '';
          initialized.value = true;
        }

        Future<void> handleSave() async {
          FocusScope.of(context).unfocus();
          final controller = ref.read(
            nightscoutSettingsControllerProvider.notifier,
          );
          controller.clearFailure();
          if (!(formKey.currentState?.validate() ?? false)) return;

          final saved = await controller.save(
            NightscoutSettingsDraft(
              url: urlController.text,
              token: tokenController.text,
              tempTargetsEnabled: tempTargetsEnabled.value,
              childName: childNameController.text,
              dataSourceConfig: visibleDataSourceConfig,
            ),
          );
          if (context.mounted && saved) {
            context.router.replace(NamedRoute('DashboardRoute'));
          }
        }

        return Scaffold(
          appBar: AppBar(title: Text(context.lang.settingsTitle)),
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
                    const SizedBox(height: 16),
                    const ApplicationThemeSettingsSection(),
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      icon: Icons.language_outlined,
                      title: context.lang.settingsLanguageTitle,
                      subtitle: context.lang.settingsLanguageSubtitle,
                      children: [
                        languageAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (error, _) => Text(
                            context.lang.settingsLanguageReadError(error),
                          ),
                          data: (language) => ApplicationLanguageSelector(
                            value: language,
                            onChanged: (value) async {
                              final errorMessage =
                                  context.lang.settingsLanguageSaveError;
                              try {
                                await ref
                                    .read(
                                      applicationLanguageControllerProvider
                                          .notifier,
                                    )
                                    .setLanguage(value);
                                ref
                                    .read(appEventRouterProvider)
                                    .send(
                                      ExecuteCommandEvent.syncSettings(
                                        data: {
                                          applicationLanguageCodeKey:
                                              value.code,
                                        },
                                      ),
                                    );
                              } catch (e, st) {
                                logE(
                                  'Language settings save failed',
                                  error: e,
                                  stackTrace: st,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(errorMessage)),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    NightscoutSettingsSection(
                      urlController: urlController,
                      tokenController: tokenController,
                      childNameController: childNameController,
                      tempTargetsEnabled: tempTargetsEnabled.value,
                      urlRequired:
                          (visibleDataSourceConfig?.usesCloud ?? true) ||
                          tempTargetsEnabled.value ||
                          tokenController.text.trim().isNotEmpty,
                      saveState: saveState,
                      onChanged: () => ref
                          .read(nightscoutSettingsControllerProvider.notifier)
                          .clearFailure(),
                      onTempTargetsChanged: (value) {
                        tempTargetsEnabled.value = value;
                        ref
                            .read(nightscoutSettingsControllerProvider.notifier)
                            .clearFailure();
                      },
                      onSave: handleSave,
                    ),
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      icon: Icons.receipt_long_outlined,
                      title: context.lang.settingsLogsTitle,
                      subtitle: context.lang.settingsLogsSubtitle,
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
                              label: Text(context.lang.settingsLogsUi),
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
                              label: Text(context.lang.settingsLogsForeground),
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
}
