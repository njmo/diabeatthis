import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/common/widgets/meal_category_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('compact category opens choices, selects lunch and validates', (
    tester,
  ) async {
    MealCategory? selected;
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              key: form,
              child: MealCategoryField(
                compact: true,
                requiredSelection: true,
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(PopupMenuItem<MealCategory>), findsNothing);
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    await tester.tap(find.text('Wybierz rodzaj posiłku'));
    await tester.pumpAndSettle();
    expect(find.byType(PopupMenuItem<MealCategory>), findsNWidgets(6));
    await tester.tap(find.widgetWithText(PopupMenuItem<MealCategory>, 'Obiad'));
    await tester.pumpAndSettle();
    expect(selected, MealCategory.lunch);
    expect(find.byType(PopupMenuItem<MealCategory>), findsNothing);
    expect(find.text('Obiad'), findsOneWidget);
    expect(form.currentState!.validate(), isTrue);
  });
}
