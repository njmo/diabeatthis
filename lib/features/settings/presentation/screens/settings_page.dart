import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/providers/app_event_router_provider.dart';
import '../../../../app/providers/app_foreground_bridge_provider.dart';
import '../../../../common/events/data/app/dump_logs_event.dart';
import '../../../../common/events/data/app/execute_command_event.dart';
import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data/repository/nightscout_repository_impl.dart';
import '../../../../core/logger/logger.dart';
import '../widgets/database_settings_section.dart';
import '../widgets/settings_section_card.dart';

const _nightscoutUrlKey = 'nightscout_url';
const _childNameKey = 'main-user-name';

@RoutePage()
class SettingsPage extends HookConsumerWidget with Logging {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefsAsync = ref.watch(sharedPrefsProvider);

    final formKey = useMemoized(GlobalKey<FormState>.new);
    final urlController = useTextEditingController();
    final childNameController = useTextEditingController();

    final initialized = useState(false);
    final isSaving = useState(false);
    final submitError = useState<String?>(null);

    return prefsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Błąd: $e'))),
      data: (prefs) {
        if (!initialized.value) {
          urlController.text = prefs.getString(_nightscoutUrlKey) ?? '';
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
          final newChildName = childNameController.text.trim();

          final oldUrl = prefs.getString(_nightscoutUrlKey)?.trim() ?? '';
          logI('oldUrl: $oldUrl');
          final oldChildName = prefs.getString(_childNameKey)?.trim() ?? '';

          final urlChanged = newUrl != oldUrl;
          final childNameChanged = newChildName != oldChildName;

          isSaving.value = true;

          try {
            if (urlChanged) {
              final repo = NightscoutRepositoryImpl(nightscoutUrl: newUrl);
              await repo.fetchLastGlucoseWithLimit(1);
            }

            if (urlChanged) {
              await prefs.setString(_nightscoutUrlKey, newUrl);
            }

            if (childNameChanged) {
              await prefs.setString(_childNameKey, newChildName);
            }

            if (urlChanged || childNameChanged) {
              ref.invalidate(sharedPrefsProvider);
              ref.invalidate(nightscoutRepositoryProvider);
            }

            if (urlChanged) {
              final foregroundBridge = ref.read(appForegroundBridgeProvider);

              if (oldUrl.isEmpty) {
                logI("starting service");
                foregroundBridge.startMonitoring();
              } else {
                logI("restarting service");
                foregroundBridge.restartService();
              }

              await Future.delayed(Duration(seconds: 4));

              ref
                  .read(appEventRouterProvider)
                  .send(ExecuteCommandEvent.syncData(data: []));
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
                    SettingsSectionCard(
                      icon: Icons.cloud_outlined,
                      title: 'Nightscout',
                      subtitle:
                          'Podaj adres swojego Nightscout. Bez niego nie możemy pobrać danych.',
                      children: [
                        TextFormField(
                          controller: urlController,
                          decoration: const InputDecoration(
                            labelText: 'Nightscout URL',
                            hintText: 'https://twoj-nightscout.com',
                          ),
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          validator: (value) {
                            final text = value?.trim() ?? '';

                            if (text.isEmpty) {
                              return 'Podaj adres Nightscout';
                            }

                            final uri = Uri.tryParse(text);
                            if (uri == null ||
                                !uri.hasScheme ||
                                (uri.scheme != 'http' &&
                                    uri.scheme != 'https') ||
                                uri.host.isEmpty) {
                              return 'Podaj poprawny adres URL';
                            }

                            return null;
                          },
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
