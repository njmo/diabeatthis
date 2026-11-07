import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/fab_action_option.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_dashboard_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'caregiver has full photo tile and two half planning tiles at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var photos = 0;
        var meals = 0;
        var activities = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              floatingActionButton: CaregiverDashboardFab(
                onPhoto: () => photos++,
                onMeal: () => meals++,
                onActivity: () => activities++,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        final tiles = find.byType(FabActionOption);
        expect(tiles, findsNWidgets(3));
        final photo = tester.getRect(tiles.at(0));
        final meal = tester.getRect(tiles.at(1));
        final activity = tester.getRect(tiles.at(2));
        expect(photo.width, greaterThan(meal.width * 1.8));
        expect(meal.top, activity.top);
        expect(meal.width, activity.width);
        expect(photo.bottom, lessThan(meal.top));
        for (var i = 0; i < 3; i++) {
          if (i > 0) {
            await tester.tap(find.byType(FloatingActionButton));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.byType(FabActionOption).at(i));
          await tester.pumpAndSettle();
          expect(find.byType(FabActionOption), findsNothing);
        }
        expect([photos, meals, activities], [1, 1, 1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
