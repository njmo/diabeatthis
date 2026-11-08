import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_snapshot.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/meal_decision_demo_glucose_history.dart';
import 'package:diabeatthis/common/widgets/inline_status_notice.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'past target is a grey historical window and flat info strip, not a current target',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('en'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      final now = DateTime(2026, 11, 8, 12);
      final snapshot = MealDecisionDemoSnapshot(
        capturedAt: now,
        targetStartedAt: now.subtract(const Duration(minutes: 20)),
        targetEndedAt: now.subtract(const Duration(minutes: 10)),
        extendedCarbsRemaining: 0,
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
      final chart = tester.widgetList<LineChart>(find.byType(LineChart)).first;
      final range = chart.data.rangeAnnotations.verticalRangeAnnotations.single;
      expect(range.x1, 10);
      expect(range.x2, 20);
      expect(chart.data.extraLinesData.horizontalLines, isEmpty);
      expect(find.byType(InlineStatusNotice), findsOneWidget);
      expect(find.text('Target 100 mg/dl · 11:40–11:50'), findsOneWidget);
      expect(find.text('Now · 12:00'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
