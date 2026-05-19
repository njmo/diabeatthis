import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../controllers/initial_configuration_controller.dart';
import '../widgets/data_source_config_controls.dart';
import '../widgets/settings_section_card.dart';

@RoutePage()
class InitialConfigurationPage extends HookConsumerWidget {
  const InitialConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(
      initialConfigurationControllerProvider.notifier,
    );
    final stateAsync = ref.watch(initialConfigurationControllerProvider);
    final availabilityAsync = ref.watch(dataSourceOptionAvailabilityProvider);
    final formKey = useMemoized(GlobalKey<FormState>.new);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pierwsza konfiguracja'),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Błąd: $error')),
        data: (state) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSectionCard(
                    icon: Icons.hub_outlined,
                    title: 'Źródła danych',
                    subtitle:
                        'Wybierz źródło cukru, zdarzeń, statusu pompy i historii.',
                    children: [
                      availabilityAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) =>
                            Text('Błąd dostępności źródeł: $error'),
                        data: (availability) => DataSourceConfigControls(
                          config: state.config,
                          availability: availability,
                          onChanged: controller.setDataSourceConfig,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.person_outline,
                    title: 'Preferencje użytkownika',
                    subtitle: 'Imię wyświetlane w aplikacji.',
                    children: [
                      TextFormField(
                        initialValue: state.userName,
                        decoration: const InputDecoration(
                          labelText: 'Imię użytkownika',
                          hintText: 'Oliwier',
                        ),
                        textCapitalization: TextCapitalization.words,
                        onSaved: (value) {
                          controller.setUserName(value?.trim() ?? '');
                        },
                      ),
                    ],
                  ),
                  if (state.config.usesCloud) ...[
                    const SizedBox(height: 16),
                    SettingsSectionCard(
                      icon: Icons.cloud_outlined,
                      title: 'Nightscout',
                      subtitle:
                          'Podaj adres swojego Nightscout. Bez niego nie możemy pobrać danych.',
                      children: [
                        TextFormField(
                          initialValue: state.nightscoutUrl,
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
                          onSaved: (value) {
                            controller.setNightscoutUrl(value?.trim() ?? '');
                          },
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (state.submitError != null) ...[
                    Text(
                      state.submitError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            final formState = formKey.currentState;
                            final isValid = formState?.validate() ?? false;
                            if (!isValid) return;

                            formState?.save();
                            final didSubmit = await controller.submit();
                            if (didSubmit && context.mounted) {
                              context.router.replace(
                                NamedRoute('DashboardRoute'),
                              );
                            }
                          },
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Zakończ konfigurację'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
