import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/setup/domain/setup_feature_option.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import '../controllers/initial_configuration_controller.dart';
import 'setup_wizard.dart';
import 'setup_wizard_state.dart';

class SetupWizardPreviewPage extends ConsumerWidget {
  const SetupWizardPreviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(initialConfigurationControllerProvider);
    final availability = ref.watch(dataSourceOptionAvailabilityProvider);
    return draft.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.lang.settingsGenericError(error))),
      ),
      data: (value) => availability.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text(context.lang.settingsGenericError(error))),
        ),
        data: (sources) => SetupWizard(
          availability: sources,
          initialState: SetupWizardState(
            config: value.config,
            language: value.language,
            name: value.userName,
            nightscoutUrl: value.nightscoutUrl,
            nightscoutToken: value.nightscoutToken,
            initialOptions: {
              if (value.tempTargetsEnabled)
                SetupFeatureOptionId.activityTempTargetUpload,
              if (value.lowTreatmentsEnabled)
                SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
            },
          ),
        ),
      ),
    );
  }
}
