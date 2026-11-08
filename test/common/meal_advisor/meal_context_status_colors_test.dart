import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_context_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final state in ['healthy', 'old', 'missing', 'failed', 'loading']) {
    testWidgets('sync status uses an honest icon and color for $state', (
      tester,
    ) async {
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
                glucoseAt: state == 'old'
                    ? now.subtract(const Duration(minutes: 6))
                    : now,
                iobAt: state == 'missing' ? null : now,
                cobAt: now,
                syncFailed: state == 'failed',
                syncing: state == 'loading',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state == 'healthy') {
          final icon = tester.widget<Icon>(
            find.byIcon(Icons.check_circle_outline),
          );
          expect(icon.color, Colors.green.shade400);
          expect(find.text('Readings are up to date'), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.check_circle_outline), findsNothing);
          if (state == 'failed') {
            expect(find.byIcon(Icons.error_outline), findsOneWidget);
            expect(find.text('Synchronization failed'), findsOneWidget);
          }
          if (state == 'old') {
            expect(
              tester
                  .widget<Icon>(find.byIcon(Icons.warning_amber_rounded))
                  .color,
              Colors.amber.shade600,
            );
          }
          if (state == 'loading') {
            expect(find.byIcon(Icons.sync), findsOneWidget);
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    });
  }
}
