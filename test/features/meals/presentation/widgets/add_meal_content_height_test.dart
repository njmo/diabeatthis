import 'package:diabeatthis/common/widgets/form_action_bar.dart';
import 'package:diabeatthis/common/widgets/keyboard_aware_sheet_frame.dart';
import 'package:diabeatthis/common/widgets/sheet_choice_tile.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('empty composition fits both choices above its fixed footer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: const Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: KeyboardAwareSheetFrame(child: AddMealPage()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lastChoice = find.widgetWithText(
      SheetChoiceTile,
      'Użyj wcześniejszego posiłku',
    );
    final footer = find.byType(FormActionBar);
    expect(
      tester.getBottomLeft(lastChoice).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy),
    );
    expect(lastChoice.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
