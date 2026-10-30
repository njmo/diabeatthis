import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showSelector(
    WidgetTester tester,
    ValueChanged<double> onChanged,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FriendlyAmountSelector(
            value: 200,
            min: 1,
            max: 1000,
            step: 5,
            options: const [],
            valueLabel: (value) => '${value.toInt()} g',
            onChanged: onChanged,
          ),
        ),
      ),
    );
    await tester.tap(find.text('200 g'));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the value allows entering an exact weight', (
    tester,
  ) async {
    double? result;
    await showSelector(tester, (value) => result = value);
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(
      field.controller!.selection.textInside(field.controller!.text),
      '200',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Zatwierdź'));
    await tester.pumpAndSettle();
    expect(result, 500);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final text in ['2,5', '2.5']) {
    testWidgets('accepts decimal input $text and keyboard confirmation', (
      tester,
    ) async {
      double? result;
      await showSelector(tester, (value) => result = value);
      await tester.enterText(find.byType(TextFormField), text);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 2.5);
    });
  }

  testWidgets('cancel does not apply the edited amount', (tester) async {
    double? result;
    await showSelector(tester, (value) => result = value);
    await tester.enterText(find.byType(TextFormField), '500');
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('rejects invalid and out-of-range numbers', (tester) async {
    double? result;
    await showSelector(tester, (value) => result = value);
    for (final text in ['', 'abc', 'NaN', 'Infinity', '0', '1001']) {
      await tester.enterText(find.byType(TextFormField), text);
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(result, isNull);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        text,
      );
    }
  });
}
