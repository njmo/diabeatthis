import 'dart:async';

import 'package:diabeatthis/features/meals/data/model/copied_meal_type.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final applied in [false, true]) {
    testWidgets(
      'updates source label only after successful copying ($applied)',
      (tester) async {
        final original = CopiedMealFromMeal(
          id: 1,
          name: 'Original',
          date: DateTime(2026),
          copiedFromMealId: null,
          copiedFromTemplateId: null,
        );
        final selected = CopiedMealFromTemplate(
          id: 2,
          name: 'Selected',
          date: DateTime(2026),
          copiedFromMealId: null,
        );
        final completion = Completer<bool>();
        final fieldKey = GlobalKey<FormFieldState<CopiedMealType?>>();
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: CopiedMealFormField(
                key: fieldKey,
                initialValue: original,
                picker: (_) async => selected,
                onPicked: (source) {
                  expect(source, same(selected));
                  return completion.future;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.byType(InkWell));
        await tester.pump();
        expect(fieldKey.currentState!.value, same(original));
        expect(find.textContaining('Original'), findsOneWidget);

        completion.complete(applied);
        await tester.pumpAndSettle();
        expect(
          fieldKey.currentState!.value,
          same(applied ? selected : original),
        );
        expect(
          find.textContaining(applied ? 'Selected' : 'Original'),
          findsOneWidget,
        );
      },
    );
  }
}
