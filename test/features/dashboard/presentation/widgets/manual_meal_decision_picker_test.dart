import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_fields.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_picker_field.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('decision picker covers save outside a nested navigator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = const ManualMealDecision();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => Center(
                    child: ManualMealDecisionFields(
                      value: selected,
                      onChanged: (value) => setState(() => selected = value),
                    ),
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: FilledButton(
              onPressed: () {},
              child: const Text('Zapisz posiłek'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Zapisz posiłek');
    final saveCenter = tester.getCenter(save);
    await tester.tap(find.byType(ManualMealDecisionPickerField));
    await tester.pumpAndSettle();
    final sheet = find.byType(ManualMealDecisionPickerSheet);
    expect(sheet, findsOneWidget);
    expect(tester.getRect(sheet).contains(saveCenter), isTrue);
    expect(save.hitTestable(), findsNothing);
    await tester.tap(
      find.descendant(
        of: sheet,
        matching: find.text('Insulina, czekanie, jedzenie'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected.decision, MealDecision.bolusWaitThenEat);
    expect(sheet, findsNothing);
    expect(save.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
