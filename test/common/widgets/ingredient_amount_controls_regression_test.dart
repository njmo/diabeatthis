import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  Future<void> showAmount(
    WidgetTester tester, {
    required double initial,
    required double step,
    required ValueChanged<double> onChanged,
  }) async {
    var current = initial;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return FriendlyAmountSelector(
                value: current,
                step: step,
                options: const [],
                valueLabel: (value) => '$value',
                onChanged: (value) {
                  setState(() => current = value);
                  onChanged(value);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'portion quantities support repeated half portions and zero clamp',
    (tester) async {
      final amounts = <double>[];
      await showAmount(tester, initial: 1, step: 0.5, onChanged: amounts.add);
      await tester.tap(find.text('+0,5'));
      await tester.pump();
      await tester.tap(find.text('+0,5'));
      await tester.pump();
      await tester.tap(find.text('-1'));
      await tester.pump();
      await tester.tap(find.text('-0,5'));
      await tester.pump();
      await tester.tap(find.text('-1'));
      await tester.pump();
      expect(amounts, [1.5, 2, 1, 0.5, 0]);
      await tester.tap(find.text('-0,5'));
      await tester.pump();
      expect(amounts, [1.5, 2, 1, 0.5, 0]);
    },
  );

  testWidgets('gram controls preserve exact one and five gram changes', (
    tester,
  ) async {
    final amounts = <double>[];
    await showAmount(tester, initial: 150, step: 5, onChanged: amounts.add);
    for (final action in ['+5', '+1', '-5', '-1']) {
      await tester.tap(find.text(action));
      await tester.pump();
    }
    expect(amounts, [155, 156, 151, 150]);
  });
}
