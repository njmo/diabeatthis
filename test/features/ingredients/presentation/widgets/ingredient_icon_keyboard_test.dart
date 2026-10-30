import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('icon search results remain reachable above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: Scaffold(
            body: IngredientIconButton(name: 'Jogurt', onSelected: (_) {}),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Wybierz ikonę'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mąka owsiana');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Mąka owsiana'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mąka owsiana').hitTestable(), findsOneWidget);
    expect(
      tester.getBottomRight(find.byType(CustomScrollView)).dy,
      lessThanOrEqualTo(440),
    );
    expect(tester.takeException(), isNull);
  });
}
