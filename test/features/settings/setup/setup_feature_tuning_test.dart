import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_configuration_field.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature_option.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/widgets/nightscout_connection_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

SetupWizardState featureTuningDraft() =>
    SetupWizardState(
        config: const DataSourceConfig(
          bgSource: BgSource.aaps,
          treatmentsSource: TreatmentsSource.aaps,
          pumpStatusSource: PumpStatusSource.aaps,
          historySource: HistorySource.local,
          mirrorToLocal: false,
        ),
        language: applicationLanguageByCode('pl'),
        name: 'Child',
        nightscoutUrl: '',
        nightscoutToken: '',
      )
      ..selected.clear()
      ..step = SetupStep.configuration.index;

void main() {
  test(
    'core low treatment monitor cannot be disabled and requires background execution',
    () {
      final controller = SetupWizardController(featureTuningDraft());
      addTearDown(controller.dispose);
      controller.select(SetupFeatureId.lowTreatment, false);
      controller.skipModule();
      expect(
        controller.selected.map((feature) => feature.id),
        containsAll([SetupFeatureId.dataAndMeals, SetupFeatureId.lowTreatment]),
      );
      expect(controller.module, SetupModule.data);
      expect(controller.requirements[SetupRequirement.backgroundExecution], {
        SetupFeatureId.lowTreatment,
      });
      expect(controller.state.enabledOptions, isEmpty);
      expect(controller.requiredConfiguration, isEmpty);
    },
  );
  test(
    'skipping local-only Nightscout disables uploads without removing monitors',
    () {
      final state = featureTuningDraft()
        ..selected.add(SetupFeatureId.activityMonitor);
      final controller = SetupWizardController(state);
      addTearDown(controller.dispose);
      for (final option in SetupFeatureOptionId.values) {
        controller.selectOption(option, true);
      }
      state.moduleIndex = controller.modules.indexOf(SetupModule.nightscout);
      controller.skipModule();
      expect(state.enabledOptions, isEmpty);
      expect(controller.requiredConfiguration, isEmpty);
      expect(
        controller.selected.map((feature) => feature.id),
        containsAll([
          SetupFeatureId.activityMonitor,
          SetupFeatureId.lowTreatment,
        ]),
      );
      expect(state.config.usesCloud, isFalse);
      expect(controller.modules, isNot(contains(SetupModule.nightscout)));
    },
  );
  test('disabled parent options do not leak requirements between modes', () {
    final controller = SetupWizardController(
      featureTuningDraft()..selected.add(SetupFeatureId.activityMonitor),
    );
    addTearDown(controller.dispose);
    controller.selectOption(
      SetupFeatureOptionId.activityTempTargetUpload,
      true,
    );
    expect(controller.requiredConfiguration, isNotEmpty);
    controller.select(SetupFeatureId.activityMonitor, false);
    expect(controller.requiredConfiguration, isEmpty);
    controller.setMode(SetupDeviceMode.caregiver);
    expect(controller.state.enabledOptions, isEmpty);
    expect(controller.requiredConfiguration.keys, [
      SetupConfigurationField.nightscoutUrl,
    ]);
    expect(
      controller.requiredConfiguration[SetupConfigurationField.nightscoutUrl],
      {SetupFeatureId.nightscoutOverview},
    );
    expect(
      controller.selected.any(
        (feature) => feature.id == SetupFeatureId.lowTreatment,
      ),
      isFalse,
    );
  });
  testWidgets(
    'activity and low treatment tuning precede Nightscout and retain choices',
    (tester) async {
      final draft = featureTuningDraft()
        ..selected.add(SetupFeatureId.activityMonitor)
        ..moduleIndex = 1;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      expect(wizard.controller.module, SetupModule.activity);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(draft.enabledOptions, {
        SetupFeatureOptionId.activityTempTargetUpload,
      });
      expect(wizard.controller.modules, [
        SetupModule.data,
        SetupModule.activity,
        SetupModule.lowTreatment,
        SetupModule.nightscout,
      ]);
      expect(find.text('Zatwierdź opcje'), findsNothing);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(wizard.controller.module, SetupModule.lowTreatment);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.text('Zatwierdź opcje'), findsNothing);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(wizard.controller.module, SetupModule.nightscout);
      expect(
        tester
            .widget<NightscoutConnectionFields>(
              find.byType(NightscoutConnectionFields),
            )
            .tokenRequired,
        isTrue,
      );
      await tester.tap(find.text('Poprzednia funkcja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Poprzednia funkcja'));
      await tester.pumpAndSettle();
      expect(wizard.controller.module, SetupModule.activity);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
