import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/family/family_management_context.dart';
import '../../../../common/family/family_providers.dart';
import '../../../../common/family_chat/data/family_chat_preferences_provider.dart';
import '../../../../common/family_chat/domain/family_chat_preferences.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/meal_advisor/meal_decision_preferences.dart';
import '../../../../common/meal_advisor/meal_decision_preferences_provider.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../common/setup/platform/native_setup_permission_gateway.dart';
import '../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../../../../core/notifications/providers/notification_retry_preferences.dart';
import '../../application/validate_setup_nightscout_use_case.dart';
import '../controllers/initial_configuration_controller.dart';
import '../setup/setup_wizard.dart';
import '../setup/setup_wizard_state.dart';

@RoutePage()
class InitialConfigurationPage extends ConsumerWidget {
  const InitialConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(initialConfigurationControllerProvider);
    final availability = ref.watch(dataSourceOptionAvailabilityProvider);
    final retryPreference = ref.watch(notificationRetriesEnabledProvider);
    if (retryPreference.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Future<bool> saveWithRetries(
      SetupWizardState value,
      Future<bool> Function() apply,
    ) async {
      try {
        final saved = await configureNotificationRetries(
          value.notificationRetrySelection,
          apply,
        );
        if (saved && context.mounted) {
          ref.invalidate(notificationRetriesEnabledProvider);
        }
        return saved;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.lang.notificationRetrySaveError)),
          );
        }
        return false;
      }
    }

    return state.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(child: Text(context.lang.settingsGenericError(error))),
      ),
      data: (draft) => availability.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          body: Center(
            child: Text(
              context.lang.settingsDataSourcesAvailabilityError(error),
            ),
          ),
        ),
        data: (sources) => SetupWizard(
          loadFamilyChatPreferences: (uid) async {
            if (ref.read(sharedPrefsProvider).hasError) {
              ref.invalidate(sharedPrefsProvider);
            }
            final prefs = await ref.read(sharedPrefsProvider.future);
            final saved = prefs.getString(familyChatPreferencesKey(uid));
            return saved == null ? null : FamilyChatPreferences.decode(saved);
          },
          familyRepository: ref.watch(secureFamilyRepositoryProvider),
          familyContext: FamilyManagementContext.initialSetup,
          authentication: ref.read(googleAuthenticationRepositoryProvider),
          permissions: const NativeSetupPermissionGateway(),
          checkNightscoutConnection: ref.read(validateSetupNightscoutProvider),
          availability: sources,
          saving: draft.isSaving,
          saveError: draft.submitError,
          initialState: SetupWizardState(
            initialNotificationRetriesEnabled:
                retryPreference.asData?.value ?? true,
            familyChatPreferences:
                ref.watch(googleAccountProvider).asData?.value == null
                ? const FamilyChatPreferences()
                : ref.watch(familyChatPreferencesProvider).asDraft(),
            mealDecisionPreferences: ref.watch(mealDecisionPreferencesProvider),
            config: draft.config,
            language: draft.language,
            name: draft.userName,
            nightscoutUrl: draft.nightscoutUrl,
            nightscoutToken: draft.nightscoutToken,
            initialOptions: {
              if (draft.tempTargetsEnabled)
                SetupFeatureOptionId.activityTempTargetUpload,
              if (draft.lowTreatmentsEnabled)
                SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
            },
          ),
          onSaveCaregiver: (value) async {
            final controller = ref.read(
              initialConfigurationControllerProvider.notifier,
            );
            controller.setUserName(value.name);
            controller.setLanguage(value.language);
            final saved = await saveWithRetries(
              value,
              () => ref.read(configureFamilyChatPreferencesProvider)(
                value.familyChatPreferences,
                (binding) => controller.submitCaregiver(
                  chatSetupBinding: binding,
                  mealDecisionPreferences: value.mealDecisionPreferences
                      .copyWith(
                        method: MealDecisionMethod.app,
                        caregiverResponsesEnabled:
                            value.selected.contains(
                              SetupFeatureId.caregiverMealDecisions,
                            ) &&
                            value
                                .mealDecisionPreferences
                                .caregiverResponsesEnabled,
                      ),
                  url: value.nightscoutUrl,
                  token: value.nightscoutToken,
                ),
                expectedUid: value.googleAccount?.uid,
              ),
            );
            if (saved && context.mounted) {
              context.router.replace(NamedRoute('DashboardRoute'));
            }
            return saved;
          },
          onSavePatient: (value) async {
            final controller = ref.read(
              initialConfigurationControllerProvider.notifier,
            );
            controller.setUserName(value.name);
            controller.setLanguage(value.language);
            controller.setDataSourceConfig(value.config);
            final saved = await saveWithRetries(
              value,
              () => ref.read(configureFamilyChatPreferencesProvider)(
                value.shareData ? value.familyChatPreferences : null,
                (binding) => controller.submit(
                  chatSetupBinding: binding,
                  mealDecisionPreferences: value.mealDecisionPreferences,
                  enableFamilySharing: value.shareData,
                  tempTargetsEnabled: value.enabledOptions.contains(
                    SetupFeatureOptionId.activityTempTargetUpload,
                  ),
                  lowTreatmentsEnabled: value.enabledOptions.contains(
                    SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
                  ),
                  nightscoutUrl: value.nightscoutUrl,
                  nightscoutToken: value.nightscoutToken,
                ),
                expectedUid: value.googleAccount?.uid,
              ),
            );
            if (saved && context.mounted) {
              context.router.replace(NamedRoute('DashboardRoute'));
            }
            return saved;
          },
        ),
      ),
    );
  }
}
