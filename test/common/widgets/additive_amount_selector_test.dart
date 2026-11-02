import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final example in [
    (
      initial: 150.0,
      step: 5.0,
      inner: 1.0,
      increment: 100.0,
      chip: '+100 g',
      result: 350.0,
    ),
    (
      initial: 1.0,
      step: 1.0,
      inner: 0.5,
      increment: 0.5,
      chip: '+0,5 porcji',
      result: 2.0,
    ),
  ]) {
    testWidgets('${example.chip} adds repeatedly to the current amount', (
      tester,
    ) async {
      var amount = example.initial;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FriendlyAmountSelector(
                  value: amount,
                  step: example.step,
                  innerStep: example.inner,
                  additiveOptions: true,
                  options: [
                    FriendlyAmountOption(
                      label: example.chip,
                      value: example.increment,
                    ),
                  ],
                  valueLabel: (value) => '$value',
                  onChanged: (value) => setState(() => amount = value),
                );
              },
            ),
          ),
        ),
      );
      for (var tap = 0; tap < 2; tap++) {
        await tester.tap(find.widgetWithText(ActionChip, example.chip));
        await tester.pump();
      }
      expect(amount, example.result);
      expect(find.byType(ChoiceChip), findsNothing);
      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .toList();
      final outer = example.step == 5 ? '5' : '1';
      final inner = example.inner == 1 ? '1' : '0,5';
      expect(labels.indexOf('-$outer'), lessThan(labels.indexOf('-$inner')));
      expect(labels.indexOf('+$inner'), lessThan(labels.indexOf('+$outer')));
    });
  }

  testWidgets('legacy quick options still select an absolute value', (
    tester,
  ) async {
    double? result;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: FriendlyAmountSelector(
            value: 150,
            options: const [FriendlyAmountOption(label: '100 g', value: 100)],
            valueLabel: (value) => '$value',
            onChanged: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, '100 g'));
    expect(result, 100);
  });
}
