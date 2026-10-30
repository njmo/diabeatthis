import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/carbohydrate_icon.dart';
import 'package:diabeatthis/common/widgets/nutrition_metric_tile.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'home, day, history and catalog remain reachable beside the center add button',
    (tester) async {
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            bottomNavigationBar: DashboardBottomBar(
              selectedIndex: 0,
              onSelected: (index) => selected = index,
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      for (final (label, index) in [
        ('Start', 0),
        ('Dzień', 1),
        ('Historia', 2),
        ('Katalog', 3),
      ]) {
        await tester.tap(find.byTooltip(label));
        expect(selected, index);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'active insulin and carbohydrate labels fit narrow screens with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: NutritionMetricTile(
                        label: 'IOB',
                        iconSize: 30,
                        iconSpacing: 16,
                        value: '12.34 U',
                        icon: Icons.water_drop_outlined,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: NutritionMetricTile(
                        label: 'COB',
                        iconSize: 30,
                        iconSpacing: 16,
                        value: '123.45 g',
                        leading: CarbohydrateIcon(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('12.34 U'), findsOneWidget);
      expect(find.text('123.45 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
