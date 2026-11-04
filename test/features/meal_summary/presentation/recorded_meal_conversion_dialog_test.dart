import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/recorded_meal_conversion_request.dart';
import 'package:diabeatthis/common/widgets/meal_completion/recorded_meal_conversion_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final suggestion in [null, 45.0]) {
    testWidgets(
      'review accepts a custom comma-decimal weight; suggestion=$suggestion',
      (tester) async {
        double? result;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Open'),
                  onPressed: () async {
                    result = await showDialog<double>(
                      context: context,
                      builder: (_) => RecordedMealConversionDialog(
                        request: RecordedMealConversionRequest(
                          entryId: 1,
                          mealId: 1,
                          ingredientId: 1,
                          portionId: 1,
                          ingredientName: 'Bread',
                          portionName: 'Slice',
                          currentGrams: suggestion,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final lang = tester
            .element(find.byType(RecordedMealConversionDialog))
            .lang;
        expect(find.text('Bread'), findsOneWidget);
        await tester.enterText(find.byType(TextFormField), '0');
        await tester.tap(find.text(lang.mealConversionConfirm));
        await tester.pumpAndSettle();
        expect(find.text(lang.mealConversionInvalidWeight), findsOneWidget);
        expect(result, isNull);
        await tester.enterText(find.byType(TextFormField), '32,5');
        await tester.tap(find.text(lang.mealConversionConfirm));
        await tester.pumpAndSettle();
        expect(result, 32.5);
      },
    );
  }
}
