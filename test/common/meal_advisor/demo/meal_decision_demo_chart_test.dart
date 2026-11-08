import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_snapshot.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/meal_decision_demo_glucose_history.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final target in [100.0, 250.0, null]) {
    testWidgets(
      'history keeps an explicit Now boundary without predicting values; target=$target',
      (tester) async {
        LanguageStrings.setSelectedLocale(const Locale('en'));
        addTearDown(() => LanguageStrings.setSelectedLocale(null));
        final snapshot = MealDecisionDemoSnapshot(
          capturedAt: DateTime(2026, 11, 8, 12),
          targetGlucose: target,
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: MealDecisionDemoGlucoseHistory(snapshot: snapshot),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final charts = tester
            .widgetList<LineChart>(find.byType(LineChart))
            .toList();
        expect(charts, hasLength(3));
        expect(charts.first.data.maxX, 35);
        if (target != null) {
          expect(charts.first.data.minY, lessThan(target));
          expect(charts.first.data.maxY, greaterThan(target));
        }
        expect(
          charts.first.data.extraLinesData.verticalLines.any(
            (line) => line.x == 30,
          ),
          isTrue,
        );
        expect(
          charts.first.data.extraLinesData.horizontalLines.map(
            (line) => line.y,
          ),
          target == null ? isEmpty : contains(target),
        );
        for (final chart in charts) {
          final recorded = chart.data.lineBarsData
              .expand((bar) => bar.spots)
              .where((spot) => !spot.isNull());
          expect(recorded.every((spot) => spot.x <= 30), isTrue);
        }
        expect(find.text('Now · 12:00'), findsNothing);
        expect(
          find.byIcon(Icons.info_outline),
          target == null ? findsNothing : findsOneWidget,
        );
        expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
        expect(
          charts.first.data.rangeAnnotations.verticalRangeAnnotations,
          target == null ? isEmpty : hasLength(1),
        );
        expect(
          find.textContaining('12 g remaining over 45 min'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
