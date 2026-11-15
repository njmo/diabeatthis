import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/setup/domain/setup_permission_gateway.dart';
import 'package:diabeatthis/common/setup/domain/setup_step.dart';
import 'package:diabeatthis/common/widgets/scrollable_chip_rail.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_option_availability.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/steps/setup_access_step.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_access_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

class _Permissions implements SetupPermissionGateway {
  final granted = <SetupRequirement>{};

  @override
  Future<bool> check(SetupRequirement requirement) async =>
      granted.contains(requirement);

  @override
  Future<bool> request(SetupRequirement requirement) async =>
      granted.add(requirement);
}

class _NoSystemRequirementsController extends SetupWizardController {
  _NoSystemRequirementsController(super.state);

  @override
  Map<SetupRequirement, Set<SetupFeatureId>> get requirements => {
    SetupRequirement.internet: {SetupFeatureId.mealMonitor},
  };
}

void main() {
  testWidgets(
    'no system requirements show the empty message instead of zero progress',
    (tester) async {
      final controller = _NoSystemRequirementsController(
        SetupWizardState(
          config: const DataSourceConfig.defaults(),
          language: applicationLanguageByCode('pl'),
          name: 'Test',
          nightscoutUrl: '',
          nightscoutToken: '',
        ),
      );
      addTearDown(controller.dispose);
      final keys = <SetupRequirement, GlobalKey>{};
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SetupAccessStep(controller: controller, accessCardKeys: keys),
          ),
        ),
      );
      final context = tester.element(find.byType(SetupAccessStep));
      expect(find.text(context.lang.setupNoRequirements), findsOneWidget);
      expect(find.text('Przyznane zgody: 0 z 0'), findsNothing);
      expect(find.byType(SetupAccessCard), findsNothing);
      expect(keys, isEmpty);
      expect(controller.missingSystemRequirements, isEmpty);
    },
  );

  testWidgets('progress and stable card keys follow permission changes', (
    tester,
  ) async {
    final permissions = _Permissions();
    final draft = SetupWizardState(
      config: const DataSourceConfig.defaults(),
      language: applicationLanguageByCode('pl'),
      name: 'Test',
      nightscoutUrl: '',
      nightscoutToken: '',
    )..step = SetupStep.access.index;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: SetupWizard(
          initialState: draft,
          availability: const DataSourceOptionAvailability.none(),
          permissions: permissions,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<SetupWizardViewState>(find.byType(SetupWizard));
    final step = tester.widget<SetupAccessStep>(find.byType(SetupAccessStep));
    final keys = Map.of(step.accessCardKeys);
    final total = keys.length;
    expect(find.text('Przyznane zgody: 0 z $total'), findsOneWidget);
    expect(keys.values.every((key) => key.currentContext != null), isTrue);
    // The first permission becomes granted only during validation's refresh.
    final first = state.controller.missingSystemRequirements.first;
    permissions.granted.add(first);
    final target = state.controller.missingSystemRequirements[1];
    final targetKey = keys[target]!;
    final scrollable = Scrollable.of(targetKey.currentContext!);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    await tester.tap(find.text('Dalej'));
    await tester.pumpAndSettle();
    expect(draft.currentStep, SetupStep.access);
    expect(state.controller.missingSystemRequirements.first, target);
    expect(find.text('Przyznane zgody: 1 z $total'), findsOneWidget);
    expect(
      tester
          .widget<SetupAccessStep>(find.byType(SetupAccessStep))
          .accessCardKeys,
      keys,
    );
    final viewport = tester.getRect(find.byType(SingleChildScrollView).first);
    final card = tester.getRect(find.byKey(targetKey));
    expect(card.top, greaterThanOrEqualTo(viewport.top));
    expect(card.top, lessThan(viewport.bottom));
    expect(
      scrollable.position.pixels,
      lessThan(scrollable.position.maxScrollExtent),
    );
  });

  testWidgets('exact alarms explain settings until granted', (tester) async {
    for (final granted in [false, true]) {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SetupAccessCard(
              requirement: SetupRequirement.exactAlarms,
              features: const {SetupFeatureId.mealMonitor},
              granted: granted,
              onGrant: () {},
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(SetupAccessCard));
      expect(
        find.text(context.lang.setupExactAlarmsSettingsHint),
        granted ? findsNothing : findsOneWidget,
      );
      expect(
        find.widgetWithText(
          OutlinedButton,
          granted ? 'Zgadzam się' : 'Otwórz ustawienia',
        ),
        findsOneWidget,
      );
    }
  });

  for (final width in [320.0, 430.0]) {
    testWidgets(
      'consent remains visible and disabled after grant at width $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var granted = false;
        var grants = 0;
        await tester.pumpWidget(
          localizedMaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(width == 320 ? 1.5 : 1),
              ),
              child: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SingleChildScrollView(
                    child: SetupAccessCard(
                      requirement: SetupRequirement.backgroundExecution,
                      features: const {SetupFeatureId.mealMonitor},
                      granted: granted,
                      onGrant: () => setState(() {
                        granted = true;
                        grants++;
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final button = find.widgetWithText(OutlinedButton, 'Zgadzam się');
        expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.text('Przyznano w podglądzie'), findsNothing);
        expect(find.text('Brak dostępu w podglądzie'), findsNothing);
        await tester.tap(button);
        expect(grants, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('overflow count stays separate and disappears when chips fit', (
    tester,
  ) async {
    Widget rail(int count) => localizedMaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            child: ScrollableChipRail(
              children: List.generate(
                count,
                (index) => SizedBox(
                  width: 100,
                  child: Chip(label: Text('Item $index')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(rail(5));
    await tester.pumpAndSettle();
    expect(find.text('+3'), findsOneWidget);
    final state = tester.state<ScrollableChipRailState>(
      find.byType(ScrollableChipRail),
    );
    await tester.tap(find.byTooltip('Przewiń chipy w prawo'));
    await tester.pumpAndSettle();
    expect(state.controller.offset, greaterThan(0));
    expect(find.byTooltip('Przewiń chipy w lewo'), findsOneWidget);
    await tester.pumpWidget(rail(1));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Przewiń chipy w prawo'), findsNothing);
    expect(find.byTooltip('Przewiń chipy w lewo'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'overflow count refreshes when total content width stays unchanged',
    (tester) async {
      Widget rail(List<double> widths) => localizedMaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ScrollableChipRail(
                children: [
                  for (var i = 0; i < widths.length; i++)
                    SizedBox(width: widths[i], child: Text('Item $i')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(rail([100, 100, 100, 100, 100]));
      await tester.pumpAndSettle();
      expect(find.text('+3'), findsOneWidget);
      await tester.pumpWidget(rail([100, 100, 100, 206]));
      await tester.pumpAndSettle();
      expect(find.text('+2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
