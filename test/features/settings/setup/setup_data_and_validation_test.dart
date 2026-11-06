import 'dart:async';

import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_configuration_field.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature_option.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/widgets/form_step_header.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_configuration_requirements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

SetupWizardState dataValidationDraft() =>
    SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('pl'),
        name: 'Child',
        nightscoutUrl: '',
        nightscoutToken: '',
      )
      ..step = SetupStep.configuration.index
      ..selected.clear();

void main() {
  test(
    'data and meals remain first and mandatory while Nightscout stays last',
    () {
      final controller = SetupWizardController(dataValidationDraft());
      addTearDown(controller.dispose);
      controller.select(SetupFeatureId.dataAndMeals, false);
      controller.skipModule();
      expect(controller.available.first.id, SetupFeatureId.dataAndMeals);
      expect(
        controller.selected.map((feature) => feature.id),
        contains(SetupFeatureId.dataAndMeals),
      );
      expect(controller.modules, [
        SetupModule.data,
        SetupModule.lowTreatment,
        SetupModule.nightscout,
      ]);
      expect(controller.module, SetupModule.data);
      expect(
        controller.requiredConfiguration[SetupConfigurationField.nightscoutUrl],
        {SetupFeatureId.dataAndMeals},
      );
      expect(
        controller.requiredConfiguration.containsKey(
          SetupConfigurationField.nightscoutToken,
        ),
        isFalse,
      );
    },
  );
  test(
    'automatic connection validation forwards trimmed credentials and write requirements',
    () async {
      final state = dataValidationDraft()
        ..nightscoutUrl = ' https://example.com '
        ..nightscoutToken = ' token '
        ..enabledOptions.add(
          SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        )
        ..moduleIndex = 2;
      var calls = 0;
      final controller = SetupWizardController(
        state,
        checkNightscoutConnection: (url, token, requiresWrite) async {
          calls++;
          expect(
            [url, token, requiresWrite],
            ['https://example.com', 'token', true],
          );
          return true;
        },
      );
      addTearDown(controller.dispose);
      expect(await controller.validateAndNext(), isTrue);
      expect(calls, 1);
      expect(state.configured, contains(SetupModule.nightscout));
      expect(state.currentStep, SetupStep.summary);
    },
  );
  test(
    'a failed connection check stays on Nightscout and can be retried',
    () async {
      final state = dataValidationDraft()
        ..nightscoutUrl = 'https://example.com'
        ..moduleIndex = 2;
      var calls = 0;
      final controller = SetupWizardController(
        state,
        checkNightscoutConnection: (_, _, _) async => ++calls > 1,
      );
      addTearDown(controller.dispose);
      expect(await controller.validateAndNext(), isFalse);
      expect(state.currentStep, SetupStep.configuration);
      expect(state.moduleValidationFailed, isTrue);
      expect(state.configured, isNot(contains(SetupModule.nightscout)));
      expect(await controller.validateAndNext(), isTrue);
      expect(state.currentStep, SetupStep.summary);
    },
  );
  test(
    'connection exceptions are contained and keep the module incomplete',
    () async {
      final state = dataValidationDraft()
        ..nightscoutUrl = 'https://example.com'
        ..moduleIndex = 2;
      final controller = SetupWizardController(
        state,
        checkNightscoutConnection: (_, _, _) async =>
            throw StateError('offline'),
      );
      addTearDown(controller.dispose);
      expect(await controller.validateAndNext(), isFalse);
      expect(controller.isValidating, isFalse);
      expect(state.moduleValidationFailed, isTrue);
      expect(state.configured, isNot(contains(SetupModule.nightscout)));
    },
  );
  test(
    'concurrent and stale checks cannot confirm changed credentials',
    () async {
      final pending = Completer<bool>();
      final state = dataValidationDraft()
        ..nightscoutUrl = 'https://example.com'
        ..moduleIndex = 2;
      var calls = 0;
      final controller = SetupWizardController(
        state,
        checkNightscoutConnection: (_, _, _) {
          calls++;
          return pending.future;
        },
      );
      addTearDown(controller.dispose);
      final checking = controller.validateAndNext();
      expect(await controller.validateAndNext(), isFalse);
      controller.setNightscout('https://changed.example.com', '');
      pending.complete(true);
      expect(await checking, isFalse);
      expect(calls, 1);
      expect(state.configured, isNot(contains(SetupModule.nightscout)));
      expect(state.currentStep, SetupStep.configuration);
      expect(controller.isValidating, isFalse);
    },
  );
  test('a check completing after disposal does not publish state', () async {
    final pending = Completer<bool>();
    final state = dataValidationDraft()
      ..nightscoutUrl = 'https://example.com'
      ..moduleIndex = 2;
    final controller = SetupWizardController(
      state,
      checkNightscoutConnection: (_, _, _) => pending.future,
    );
    final checking = controller.validateAndNext();
    controller.dispose();
    pending.complete(true);
    expect(await checking, isFalse);
    expect(state.configured, isNot(contains(SetupModule.nightscout)));
  });
  testWidgets(
    'Next validates Nightscout automatically and summary restores Configuration label',
    (tester) async {
      final draft = dataValidationDraft()
        ..enabledOptions.add(
          SetupFeatureOptionId.lowTreatmentCarbohydrateUpload,
        )
        ..granted.addAll([
          SetupRequirement.backgroundExecution,
          SetupRequirement.notifications,
        ]);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final controller = tester
          .state<SetupWizardViewState>(find.byType(SetupWizard))
          .controller;
      expect(controller.module, SetupModule.data);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(controller.module, SetupModule.lowTreatment);
      expect(find.text('Zatwierdź opcje'), findsNothing);
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(controller.module, SetupModule.nightscout);
      expect(find.text('Symuluj sprawdzenie dostępności'), findsNothing);
      final fields = find.byType(TextFormField);
      final dependencies = find.byType(SetupConfigurationRequirements);
      expect(
        tester.getTopLeft(dependencies.first).dy,
        greaterThan(tester.getTopLeft(fields.first).dy),
      );
      expect(
        tester.getTopLeft(dependencies.last).dy,
        greaterThan(tester.getTopLeft(fields.last).dy),
      );
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(controller.module, SetupModule.nightscout);
      expect(draft.currentStep, SetupStep.configuration);
      await tester.enterText(fields.first, 'https://example.com');
      await tester.enterText(fields.last, 'token');
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(draft.currentStep, SetupStep.summary);
      expect(draft.configured, contains(SetupModule.nightscout));
      expect(find.text('Skonfigurowane'), findsWidgets);
      final header = tester.widget<FormStepHeader>(find.byType(FormStepHeader));
      expect(header.labels, [
        'Start',
        'Rola',
        'Funkcje',
        'Dostęp',
        'Konfiguracja',
        'Gotowe',
      ]);
      expect(header.currentStep, SetupStep.summary.index);
      expect(tester.takeException(), isNull);
    },
  );
}
