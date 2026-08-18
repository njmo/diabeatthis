import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/application_language.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../controllers/initial_configuration_controller.dart';
import '../widgets/application_language_selector.dart';
import '../widgets/data_source_config_controls.dart';
import '../widgets/nightscout_connection_fields.dart';
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
        title: Text(context.lang.initialConfigurationTitle),
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.settingsGenericError(error))),
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
                    title: context.lang.settingsDataSourcesTitle,
                    subtitle: context.lang.settingsDataSourcesSubtitle,
                    children: [
                      availabilityAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, _) => Text(
                          context.lang.settingsDataSourcesAvailabilityError(
                            error,
                          ),
                        ),
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
                    icon: Icons.language_outlined,
                    title: context.lang.settingsLanguageTitle,
                    subtitle: context.lang.settingsLanguageSubtitle,
                    children: [
                      ApplicationLanguageSelector(
                        value: state.language,
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
                            controller.setLanguage(value);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(errorMessage)),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    icon: Icons.person_outline,
                    title: context.lang.settingsUserPreferencesTitle,
                    subtitle: context.lang.settingsUserPreferencesSubtitle,
                    children: [
                      TextFormField(
                        initialValue: state.userName,
                        decoration: InputDecoration(
                          labelText: context.lang.settingsUserNameLabel,
                          hintText: context.lang.settingsNameHint,
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
                      subtitle: context.lang.settingsNightscoutSubtitle,
                      children: [
                        NightscoutConnectionFields(
                          initialUrl: state.nightscoutUrl,
                          initialToken: state.nightscoutToken,
                          onUrlSaved: (value) {
                            controller.setNightscoutUrl(value?.trim() ?? '');
                          },
                          onTokenSaved: (value) {
                            controller.setNightscoutToken(value?.trim() ?? '');
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
                    label: Text(context.lang.settingsFinishConfiguration),
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
