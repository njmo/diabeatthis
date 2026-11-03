import 'package:diabeatthis/features/meals/common/widgets/show_meal_category_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'category menu stays above bottom system inset and selects an item',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 780);
      tester.view.padding = FakeViewPadding(bottom: 48);
      tester.view.viewPadding = FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);
      Object? selected;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 780),
              padding: EdgeInsets.only(bottom: 48),
              viewPadding: EdgeInsets.only(bottom: 48),
            ),
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 48),
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async {
                        selected = await showMealCategoryMenu(context);
                      },
                      child: const Text('Choose'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Kolacja'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Kolacja')).dy,
        lessThanOrEqualTo(732),
      );
      await tester.tap(find.text('Kolacja'));
      await tester.pumpAndSettle();
      expect(selected.toString(), 'MealCategory.dinner');
      expect(tester.takeException(), isNull);
    },
  );
}
