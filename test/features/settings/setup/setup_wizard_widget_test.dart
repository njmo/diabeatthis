import 'package:diabeatthis/common/ai/ai_settings_controller.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/widgets/form_step_header.dart';
import 'package:diabeatthis/common/widgets/scrollable_chip_rail.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_help_sheet.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_feature_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import '../../../helpers/regression/setup_ai_settings_controller.dart';

SetupWizardState setupDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Child',
  nightscoutUrl: '',
  nightscoutToken: '',
);

void main() {
  testWidgets(
    'six markers remain visible while fifth label and module count change',
    (tester) async {
      final draft = setupDraft()
        ..step = SetupStep.configuration.index
        ..moduleIndex = 3;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiSettingsControllerProvider.overrideWith(
              SetupAiSettingsTestController.new,
            ),
          ],
          child: localizedMaterialApp(
            home: SetupWizard(
              initialState: draft,
              availability: const DataSourceOptionAvailability.none(),
            ),
          ),
        ),
      );
      expect(
        tester.widget<FormStepHeader>(find.byType(FormStepHeader)).labels,
        ['Start', 'Rola', 'Funkcje', 'Dostęp', 'Rodzina', 'Gotowe'],
      );
      expect(find.text('Konfiguracja funkcji 4/6'), findsOneWidget);
      await tester.tap(find.text('Symuluj logowanie Google'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Symuluj parowanie'));
      await tester.tap(find.text('Symuluj parowanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej'));
      await tester.pumpAndSettle();
      expect(find.text('Konfiguracja funkcji 5/6'), findsOneWidget);
      expect(
        tester.widget<FormStepHeader>(find.byType(FormStepHeader)).labels[4],
        'AI',
      );
      await tester.tap(find.text('Poprzednia funkcja'));
      await tester.pumpAndSettle();
      expect(find.text('Konfiguracja funkcji 4/6'), findsOneWidget);
      expect(draft.paired, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'caregiver preview completion never invokes patient persistence',
    (tester) async {
      var writes = 0;
      final draft = setupDraft()
        ..mode = SetupDeviceMode.caregiver
        ..step = SetupStep.summary.index;
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
      await tester.tap(find.text('Zakończ podgląd'));
      await tester.pumpAndSettle();
      expect(find.text('Podgląd zakończony'), findsOneWidget);
      expect(writes, 0);
    },
  );

  testWidgets('feature information opens independently of its switch', (
    tester,
  ) async {
    final draft = setupDraft()..step = SetupStep.features.index;
    draft.selected.remove(SetupFeatureId.mealMonitor);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: SetupWizard(
          initialState: draft,
          availability: const DataSourceOptionAvailability.none(),
        ),
      ),
    );
    await tester.ensureVisible(
      find.byWidgetPredicate(
        (widget) =>
            widget is SetupFeatureTile &&
            widget.feature.id == SetupFeatureId.mealMonitor,
      ),
    );
    await tester.tap(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is SetupFeatureTile &&
              widget.feature.id == SetupFeatureId.mealMonitor,
        ),
        matching: find.byTooltip('Informacje o funkcji'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SetupFeatureHelpSheet), findsOneWidget);
    expect(find.text('Czytaj w GitHub Wiki'), findsOneWidget);
    expect(draft.selected.contains(SetupFeatureId.mealMonitor), isFalse);
    await tester.tap(find.text('Rozumiem'));
    await tester.pumpAndSettle();
    expect(draft.selected.contains(SetupFeatureId.mealMonitor), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dependency chips scroll horizontally and show overflow controls',
    (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: ScrollableChipRail(
                  children: List.generate(
                    5,
                    (i) => Chip(label: Text('Feature number $i')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Przewiń chipy w prawo'), findsOneWidget);
      final state = tester.state<ScrollableChipRailState>(
        find.byType(ScrollableChipRail),
      );
      await tester.tap(find.byTooltip('Przewiń chipy w prawo'));
      await tester.pumpAndSettle();
      expect(state.controller.offset, greaterThan(0));
      expect(find.byTooltip('Przewiń chipy w lewo'), findsOneWidget);
    },
  );

  testWidgets(
    'session language changes the wizard and help without persisting preferences',
    (tester) async {
      final draft = setupDraft()..step = SetupStep.features.index;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      final state = tester.state<SetupWizardViewState>(
        find.byType(SetupWizard),
      );
      draft.language = applicationLanguageByCode('en');
      state.controller.changed();
      await tester.pumpAndSettle();
      expect(find.text('What you can do'), findsOneWidget);
      await tester.ensureVisible(
        find.byWidgetPredicate(
          (widget) =>
              widget is SetupFeatureTile &&
              widget.feature.id == SetupFeatureId.mealMonitor,
        ),
      );
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate(
            (widget) =>
                widget is SetupFeatureTile &&
                widget.feature.id == SetupFeatureId.mealMonitor,
          ),
          matching: find.byTooltip('About this feature'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What it needs'), findsOneWidget);
      expect(find.text('Read in GitHub Wiki'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finishing a settings preview returns to the preceding route', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SetupWizard(
                    initialState: setupDraft()
                      ..step = SetupStep.summary.index
                      ..nightscoutUrl = 'https://example.com'
                      ..configured.add(SetupModule.nightscout),
                    availability: const DataSourceOptionAvailability.none(),
                  ),
                ),
              ),
              child: const Text('Open preview'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zakończ podgląd'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rozumiem'));
    await tester.pumpAndSettle();
    expect(find.text('Open preview'), findsOneWidget);
    expect(find.byType(SetupWizard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'system language uses the device locale including an empty configuration step',
    (tester) async {
      tester.binding.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);
      final draft = setupDraft()
        ..mode = SetupDeviceMode.caregiver
        ..step = SetupStep.configuration.index
        ..language = applicationLanguageByCode('system')
        ..config = const DataSourceConfig(
          bgSource: BgSource.aaps,
          treatmentsSource: TreatmentsSource.aaps,
          pumpStatusSource: PumpStatusSource.aaps,
          historySource: HistorySource.local,
          mirrorToLocal: false,
        );
      draft.selected.clear();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No additional configuration needed'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final step in [0, 1, 2, 3, 4]) {
    testWidgets('step $step fits a narrow display with larger text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = setupDraft()..step = step;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 760),
              textScaler: TextScaler.linear(1.5),
            ),
            child: SetupWizard(
              initialState: draft,
              availability: const DataSourceOptionAvailability.none(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow screen with larger text has no layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final draft = setupDraft()..step = SetupStep.access.index;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 760),
            textScaler: TextScaler.linear(1.3),
          ),
          child: SetupWizard(
            initialState: draft,
            availability: const DataSourceOptionAvailability.none(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
