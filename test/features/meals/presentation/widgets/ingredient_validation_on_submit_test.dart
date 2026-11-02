import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import 'package:diabeatthis/features/portions/presentation/widgets/portion_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final weight in [false, true]) {
    testWidgets('validation waits for the button (portion weight: $weight)', (
      tester,
    ) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        ProviderScope(
          child: localizedMaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  if (weight)
                    IngredientPortionAmountForm(
                      formKey: key,
                      amount: 0,
                      onAmountChanged: (_) {},
                    )
                  else
                    PortionForm(formKey: key),
                  FilledButton(
                    onPressed: () => key.currentState!.validate(),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (!weight) {
        await tester.enterText(find.byType(TextFormField).first, 'x');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
      }
      expect(key.currentState!.validateGranularly, isNotNull);
      final fields = tester.stateList<FormFieldState>(
        find.byWidgetPredicate((widget) => widget is FormField),
      );
      expect(fields.any((field) => field.hasError), isFalse);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(fields.any((field) => field.hasError), isTrue);
    });
  }
}
