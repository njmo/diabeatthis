import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/common/widgets/scrollable_chip_rail.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_access_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
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
