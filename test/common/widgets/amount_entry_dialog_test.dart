import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/amount_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rejects numbers too large for precise amount normalization', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AmountEntryDialog(value: 200, min: 0)),
      ),
    );
    for (final input in ['1e308', '9999999999999999999999']) {
      await tester.enterText(find.byType(TextFormField), input);
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(find.text('Podaj poprawną liczbę.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
