import 'package:diabeatthis/common/family_sync/presentation/family_plan_amount_label.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'reference portions are not shown as physical grams and missing weights stay unknown',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  Text(
                    familyPlanAmountLabel(
                      context,
                      {'amount': 2, 'grams_per_portion_used': 100},
                      {'is_reference': 1},
                    ),
                  ),
                  Text(
                    familyPlanAmountLabel(
                      context,
                      {'amount': 2, 'grams_per_portion_used': 35},
                      {'is_reference': 0},
                    ),
                  ),
                  Text(
                    familyPlanAmountLabel(
                      context,
                      {'amount': 2, 'grams_per_portion_used': null},
                      {'is_reference': 0},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('2 reference portions'), findsOneWidget);
      expect(find.text('70 g'), findsOneWidget);
      final context = tester.element(find.byType(Scaffold));
      expect(
        find.text(context.lang.amountMissingPortionWeight),
        findsOneWidget,
      );
    },
  );
}
