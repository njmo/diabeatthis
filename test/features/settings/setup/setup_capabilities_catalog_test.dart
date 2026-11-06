import 'dart:io';

import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/get_available_setup_features_use_case.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_help_sheet.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

const baselineCapabilities = {
  SetupFeatureId.mealPlanning,
  SetupFeatureId.activityPlanning,
  SetupFeatureId.lowTreatmentRecording,
  SetupFeatureId.ingredientLibrary,
  SetupFeatureId.mealHistory,
  SetupFeatureId.mealAnalysis,
  SetupFeatureId.dayOverview,
};

SetupWizardState capabilitiesDraft(SetupDeviceMode mode) =>
    SetupWizardState(
        config: const DataSourceConfig.defaults(),
        language: applicationLanguageByCode('pl'),
        name: 'Demo',
        nightscoutUrl: '',
        nightscoutToken: '',
      )
      ..mode = mode
      ..step = SetupStep.features.index;

void main() {
  for (final mode in SetupDeviceMode.values) {
    test(
      '$mode presents baseline tools without changing configuration modules',
      () {
        final controller = SetupWizardController(capabilitiesDraft(mode));
        addTearDown(controller.dispose);
        final modules = controller.modules.toList();
        for (final id in baselineCapabilities) {
          expect(
            controller.available
                .singleWhere((feature) => feature.id == id)
                .alwaysEnabled,
            isTrue,
          );
          controller.select(id, false);
          expect(
            controller.selected.map((feature) => feature.id),
            contains(id),
          );
        }
        expect(controller.modules, modules);
        if (mode == SetupDeviceMode.caregiver) {
          expect(
            controller.requirements.containsKey(
              SetupRequirement.backgroundExecution,
            ),
            isFalse,
          );
          expect(controller.modules, isNot(contains(SetupModule.nightscout)));
          controller.select(SetupFeatureId.familyChat, false);
          controller.select(SetupFeatureId.childOverview, false);
          expect(
            controller.modules,
            isEmpty,
            reason:
                'Descriptive capabilities must not activate a family connection',
          );
        }
      },
    );
    testWidgets(
      '$mode shows groups, read-only enabled tools and role-aware wiki help',
      (tester) async {
        final draft = capabilitiesDraft(mode);
        await tester.pumpWidget(
          localizedMaterialApp(
            home: SetupWizard(
              initialState: draft,
              availability: const DataSourceOptionAvailability.none(),
            ),
          ),
        );
        expect(find.text('Co potrafi aplikacja'), findsOneWidget);
        expect(find.text('Na co dzień'), findsOneWidget);
        expect(find.text('Historia i analiza'), findsOneWidget);
        final planning = find.byWidgetPredicate(
          (widget) =>
              widget is SetupFeatureTile &&
              widget.feature.id == SetupFeatureId.mealPlanning,
        );
        await tester.ensureVisible(planning);
        expect(tester.widget<SetupFeatureTile>(planning).selected, isTrue);
        expect(
          find.descendant(of: planning, matching: find.byType(Switch)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: planning,
            matching: find.byTooltip('Zawsze włączone'),
          ),
          findsOneWidget,
        );
        final info = find.descendant(
          of: planning,
          matching: find.byTooltip('Informacje o funkcji'),
        );
        await tester.ensureVisible(info);
        await tester.tap(info);
        await tester.pumpAndSettle();
        final sheet = tester.widget<SetupFeatureHelpSheet>(
          find.byType(SetupFeatureHelpSheet),
        );
        expect(sheet.mode, mode);
        expect(sheet.feature.wikiPage, 'Meals');
        expect(find.text('Czytaj w GitHub Wiki'), findsOneWidget);
        expect(
          find.textContaining(
            mode == SetupDeviceMode.caregiver
                ? 'Wykonanie posiłku potwierdza dziecko'
                : 'Utwórz posiłek z godziną',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Rozumiem'));
        await tester.tap(find.text('Rozumiem'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('all capability wiki destinations have a maintained source page', () {
    for (final feature in GetAvailableSetupFeaturesUseCase.catalog.where(
      (feature) => feature.wikiPage != null,
    )) {
      expect(
        File('docs/wiki/${feature.wikiPage}.md').existsSync(),
        isTrue,
        reason: '${feature.id} references an unmaintained wiki page',
      );
    }
  });
}
