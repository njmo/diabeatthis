import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_context_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fresh synchronization does not hide a reading older than five minutes',
    (tester) async {
      final now = DateTime(2026, 11, 8, 12);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealDecisionContextStatus(
                syncedAt: now,
                glucoseAt: now.subtract(const Duration(minutes: 5)),
                iobAt: now.subtract(const Duration(minutes: 5, seconds: 1)),
                cobAt: now,
                notices: const [Text('Target'), Text('Activity')],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('12:00'), findsOneWidget);
        expect(find.text('Readings older than 5 min: IOB'), findsOneWidget);
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(find.text('Target'), findsOneWidget);
        expect(find.text('Activity'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('age warnings update while the panel remains open', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 8, 12);
    await withClock(Clock(() => now), () async {
      final reading = now.subtract(const Duration(minutes: 5));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealDecisionContextStatus(
              syncedAt: now,
              glucoseAt: reading,
              iobAt: now,
              cobAt: now,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('Readings older than 5 min: Glucose'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'missing readings are identified without inventing a sync timestamp',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MealDecisionContextStatus(syncedAt: null)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No synchronization yet'), findsOneWidget);
      expect(
        find.text('Readings unavailable: Glucose, IOB, COB'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );
}
