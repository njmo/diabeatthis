import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_amount_breakdown.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_glucose_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_insulin_breakdown.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 15);
  final glucose = GlucosePeriodSummary.calculate(
    [
      for (var i = 0; i < 12; i++)
        Glucose(
          externalId: '$i',
          source: GlucoseSource.cloud,
          date: start.add(Duration(minutes: i * 5)),
          sgv: 100 + i * 10,
          direction: '',
        ),
    ],
    start,
    start.add(const Duration(hours: 1)),
  );

  Widget app(
    Widget child, {
    String language = 'pl',
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) => MaterialApp(
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(brightness: brightness),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets(
    'live chart and archived sections support narrow screens, large text and both languages',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = DaySummarySnapshot(
        dayKey: '2026-09-15',
        asOf: start,
        builtAt: start,
        utcOffsetMinutes: 120,
        metrics: {for (final metric in DaySummaryMetric.values) metric: 20},
        limitations: [],
        review: [],
      );
      final encoded = snapshot.encode();
      for (final language in ['pl', 'en']) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            app(
              Column(
                children: [
                  DayGlucoseCard(title: 'CGM', summary: glucose),
                  DaySummaryFacts(snapshot: snapshot),
                ],
              ),
              language: language,
              brightness: brightness,
              scale: 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(TimelineGlucoseChart), findsOneWidget);
          expect(find.byType(DayInsulinBreakdown), findsOneWidget);
          expect(tester.takeException(), isNull);
          for (final expansion
              in find.byType(ExpansionTile).evaluate().toList()) {
            final finder = find.byWidget(expansion.widget);
            await tester.ensureVisible(finder);
            await tester.tap(finder);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(snapshot.encode(), encoded);
        }
      }
    },
  );

  testWidgets('method explanations are available on demand beside the chart', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(DayGlucoseCard(title: 'CGM', summary: glucose)),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(DayGlucoseCard));
    final method = context.lang.dayGlucoseMethod;
    expect(find.textContaining(method), findsNothing);
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pumpAndSettle();
    expect(find.textContaining(method), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'insulin distribution excludes SMB from manual boluses and does not invent missing fractions',
    (tester) async {
      for (final basal in [4.0, null, 0.0]) {
        await tester.pumpWidget(
          app(DayInsulinBreakdown(basal: basal, boluses: 6, smb: 2)),
        );
        await tester.pumpAndSettle();
        final breakdown = tester.widget<DayAmountBreakdown>(
          find.byType(DayAmountBreakdown),
        );
        expect(breakdown.segments.map((s) => s.amount), [basal, 4.0, 2.0]);
        expect(
          find.byType(Expanded),
          basal == null ? findsNothing : findsNWidgets(basal == 0 ? 2 : 3),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
