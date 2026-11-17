import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/day/day_history_statistics.dart';
import 'package:diabeatthis/common/presentation/day/day_glucose_chart.dart';
import 'package:diabeatthis/common/presentation/day/day_insulin_card.dart';
import 'package:diabeatthis/common/widgets/data_warning_indicator.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 17);
  final nightStart = start.subtract(const Duration(hours: 2));
  final night = GlucosePeriodSummary.calculate(
    [
      Glucose(
        externalId: 'night',
        source: GlucoseSource.cloud,
        date: nightStart,
        sgv: 120,
        direction: '',
      ),
    ],
    nightStart,
    start.add(const Duration(hours: 6)),
  );
  final day = DayContext(
    start: start,
    asOf: start.add(const Duration(hours: 1)),
    builtAt: start,
    glucose: null,
    nightGlucose: night,
    boluses: null,
    nightBoluses: null,
    basal: null,
    nightBasal: null,
    meals: null,
    lowTreatments: null,
    activities: null,
    sensorAge: Duration.zero,
    podAge: null,
    failedSources: {},
  );

  testWidgets(
    'shared history retains exact night durations, missing CGM and unknown insulin at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final locale in ['pl', 'en']) {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(locale),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: DayHistoryStatistics(day: day),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final lang = tester.element(find.byType(DayHistoryStatistics)).lang;
          expect(
            find.text('${lang.dayInRange} · 100% · 5 min'),
            findsOneWidget,
          );
          expect(
            find.text('${lang.dayMissingGlucose} · 7 h 55 min'),
            findsOneWidget,
          );
          expect(find.text('${lang.dayCoverage}: 1%'), findsOneWidget);
          expect(find.text('0,00 U'), findsNothing);
          expect(find.text('0.00 U'), findsNothing);
          expect(find.byType(DayInsulinCard), findsNWidgets(2));
          expect(
            tester
                .widgetList<DataWarningIndicator>(
                  find.byType(DataWarningIndicator),
                )
                .any((warning) => warning.message.contains(lang.dayPodAge)),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.byType(DayGlucoseChart));
          final position = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          final before = position.pixels;
          await tester.drag(
            find.byType(DayGlucoseChart),
            const Offset(0, -150),
          );
          await tester.pumpAndSettle();
          expect(position.pixels, greaterThan(before));
        }
      }
    },
  );
}
