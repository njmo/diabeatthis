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

SetupWizardState requiredConfigurationDraft() => SetupWizardState(
  config: const DataSourceConfig(
    bgSource: BgSource.aaps,
    treatmentsSource: TreatmentsSource.aaps,
    pumpStatusSource: PumpStatusSource.aaps,
    historySource: HistorySource.local,
    mirrorToLocal: false,
  ),
  language: applicationLanguageByCode('pl'),
  name: 'Child',
  nightscoutUrl: 'https://example.com',
  nightscoutToken: '',
)..selected.clear();

void main() {
  for (final feature in [
    SetupFeatureId.lowTreatment,
    SetupFeatureId.activityMonitor,
  ]) {
    test(
      '$feature adds Nightscout in local mode and blocks progression without token',
      () {
        final state = requiredConfigurationDraft()
          ..step = SetupStep.configuration.index;
        final controller = SetupWizardController(state);
        addTearDown(controller.dispose);
        controller.select(feature, true);
        final option = feature == SetupFeatureId.lowTreatment
            ? SetupFeatureOptionId.lowTreatmentCarbohydrateUpload
            : SetupFeatureOptionId.activityTempTargetUpload;
        controller.selectOption(option, true);
        state.moduleIndex = controller.modules.indexOf(SetupModule.nightscout);
        expect(controller.modules.first, SetupModule.nightscout);
        expect(controller.missingConfiguration, {
          SetupConfigurationField.nightscoutToken,
        });
        controller.simulateModule(SetupModule.nightscout);
        expect(controller.next(), isFalse);
        state.configured.add(SetupModule.nightscout);
        expect(
          controller.next(),
          isFalse,
          reason: 'A completion flag cannot bypass a required field',
        );
        controller.setNightscout(state.nightscoutUrl, '  token  ');
        expect(
          controller.next(),
          isFalse,
          reason: 'Editing credentials requires a fresh check',
        );
        controller.simulateModule(SetupModule.nightscout);
        expect(controller.next(), isTrue);
        controller.selectOption(option, false);
        expect(controller.requiredConfiguration, isEmpty);
        expect(controller.modules, isNot(contains(SetupModule.nightscout)));
      },
    );
  }
  testWidgets(
    'Nightscout marks token required, validates it and then allows continuation',
    (tester) async {
      final draft = requiredConfigurationDraft()
        ..step = SetupStep.configuration.index
        ..enabledOptions.add(
          SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        )
        ..moduleIndex = 0;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final fields = tester.widget<NightscoutConnectionFields>(
        find.byType(NightscoutConnectionFields),
      );
      expect(fields.tokenRequired, isTrue);
      expect(fields.tokenLabel, endsWith('*'));
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Wybrane funkcje wysyłania wymagają tokenu Nightscout z prawem zapisu.',
        ),
        findsOneWidget,
      );
      expect(draft.configured, isNot(contains(SetupModule.nightscout)));
      await tester.enterText(find.byType(TextFormField).last, 'token');
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(draft.step, SetupStep.configuration.index);
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      expect(wizard.controller.module, SetupModule.data);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'summary cannot save a selected feature with incomplete configuration',
    (tester) async {
      var writes = 0;
      final draft = requiredConfigurationDraft()
        ..step = SetupStep.summary.index
        ..selected.add(SetupFeatureId.activityMonitor)
        ..enabledOptions.add(SetupFeatureOptionId.activityTempTargetUpload);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
            onSavePatient: (_) async {
              writes++;
              return true;
            },
          ),
        ),
      );
      final wizard = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      await wizard.next(tester.element(find.byType(SetupWizard)));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(draft.step, SetupStep.configuration.index);
      expect(wizard.controller.module, SetupModule.nightscout);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('read-only Nightscout retains optional token', (tester) async {
    final draft = requiredConfigurationDraft()
      ..config = const DataSourceConfig.defaults()
      ..step = SetupStep.configuration.index
      ..moduleIndex = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: SetupWizard(
          initialState: draft,
          availability: const DataSourceOptionAvailability.none(),
        ),
      ),
    );
    expect(
      tester
          .widget<NightscoutConnectionFields>(
            find.byType(NightscoutConnectionFields),
          )
          .tokenRequired,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
