import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_deadline_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fallback in <MealDecisionTimeoutFallback?>[
    ...MealDecisionTimeoutFallback.values,
    null,
  ]) {
    testWidgets('deadline counts down and clamps at zero: $fallback', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 1, 1, 12);
      final deadline = now.add(const Duration(minutes: 2, seconds: 5));
      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealDecisionDeadlinePanel(
                deadline: deadline,
                fallback: fallback,
              ),
            ),
          ),
        );
        expect(find.text('Time remaining: 2:05'), findsOneWidget);
        expect(
          find.text(switch (fallback) {
            MealDecisionTimeoutFallback.manual =>
              'When time runs out, the decision can be made manually.',
            MealDecisionTimeoutFallback.app =>
              'When time runs out, the Meal Advisor will prepare a suggestion.',
            null =>
              'When time runs out, the child will use the configured fallback.',
          }),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        now = now.add(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time remaining: 1:55'), findsOneWidget);
        now = deadline.add(const Duration(minutes: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Time remaining: 0:00'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      });
    });
  }
}
