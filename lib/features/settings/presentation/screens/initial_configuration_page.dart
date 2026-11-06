import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/auth/google_authentication_providers.dart';
import '../../../../common/family/family_management_context.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../common/setup/platform/native_setup_permission_gateway.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
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
          familyContext: FamilyManagementContext.initialSetup,
          authentication: ref.read(googleAuthenticationRepositoryProvider),
          permissions: const NativeSetupPermissionGateway(),
          checkNightscoutConnection: ref.read(validateSetupNightscoutProvider),
          availability: sources,
          saving: draft.isSaving,
          saveError: draft.submitError,
          initialState: SetupWizardState(
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
          onSavePatient: (value) async {
            final controller = ref.read(
              initialConfigurationControllerProvider.notifier,
            );
            controller.setUserName(value.name);
            controller.setLanguage(value.language);
            controller.setDataSourceConfig(value.config);
            final saved = await controller.submit(
              nightscoutUrl: value.nightscoutUrl,
              nightscoutToken: value.nightscoutToken,
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
