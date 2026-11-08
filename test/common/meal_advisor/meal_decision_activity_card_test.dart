import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/context/meal_decision_activity_context.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_activity_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final planned in [true, false]) {
    testWidgets(
      'activity context links to existing previews: planned=$planned',
      (tester) async {
        var openedRecord = 0;
        var openedHistory = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealDecisionActivityCard(
                activity: MealDecisionActivityContext(
                  kind: planned ? 'activities' : 'activityLogs',
                  id: 8,
                  name: 'Training',
                  at: DateTime(2026, 11, 8, 12),
                  planned: planned,
                ),
                openRecord: () => openedRecord++,
                openActivity: planned ? null : () => openedHistory++,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Training'));
        expect(openedRecord, 1);
        if (!planned) {
          await tester.tap(find.text('Activity plan and history'));
          expect(openedHistory, 1);
          expect(find.text('Session details and intensity'), findsOneWidget);
        } else {
          expect(find.text('Activity plan and history'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
