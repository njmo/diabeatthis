import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/history/glucose_window_summary.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/glucose_freshness_provider.dart';
import 'package:diabeatthis/common/presentation/day/day_chart_time.dart';
import 'package:diabeatthis/common/presentation/day/day_glucose_chart.dart';
import 'package:diabeatthis/common/presentation/day/day_glucose_coverage_warning.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

DayContext dayAt(
  DateTime start,
  DateTime end, {
  List<Glucose> readings = const [],
  bool known = true,
}) => DayContext(
  start: start,
  asOf: end,
  builtAt: end,
  glucose: known ? GlucosePeriodSummary.calculate(readings, start, end) : null,
  nightGlucose: null,
  boluses: null,
  nightBoluses: null,
  meals: null,
  lowTreatments: null,
  activities: null,
  failedSources: {},
);

void main() {
  final start = DateTime.utc(2026, 11, 18);
  for (final age in [const Duration(minutes: 1), const Duration(hours: 2)]) {
    testWidgets(
      'today last-value badge has its real measurement time and stale styling: age=$age',
      (tester) async {
        final now = start.add(const Duration(hours: 12));
        final reading = Glucose(
          externalId: 'cgm',
          source: GlucoseSource.cloud,
          date: now.subtract(age),
          sgv: 123,
          direction: 'Flat',
        );
        final day = dayAt(start, now, readings: [reading]);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              timeNowProvider.overrideWith((ref) => Stream.value(now)),
              dashboardWallClockProvider.overrideWithValue(() => now),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      DayGlucoseCoverageWarning(day: day),
                      DayGlucoseChart(day: day),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final stale = age >= const Duration(minutes: 5);
        expect(
          find.byKey(
            ValueKey(stale ? 'day-glucose-stale' : 'day-glucose-current'),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.text('123 mg/dl')).style!.decoration,
          stale ? TextDecoration.lineThrough : null,
        );
        expect(find.text(stale ? '10:00' : '11:59'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('day-glucose-coverage-warning')),
          findsOneWidget,
        );
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((widget) => widget.painter)
            .whereType<DayGlucosePainter>()
            .single;
        expect(painter.now, now);
        expect(painter.gaps.last.end, stale ? now : reading.date);
        expect(painter.gaps.any((gap) => gap.end.isAfter(now)), false);
      },
    );
  }
  test(
    'warning is strictly above ten percent of the full day, never including future hours',
    () {
      final exact = start.add(const Duration(minutes: 144));
      final day = dayAt(start, exact);
      final window = visibleDayGlucoseWindow(day, exact)!;
      expect(window.missing, const Duration(minutes: 144));
      expect(showDayGlucoseCoverageWarning(day, window), false);
      final later = visibleDayGlucoseWindow(
        day,
        exact.add(const Duration(seconds: 1)),
      )!;
      expect(showDayGlucoseCoverageWarning(day, later), true);
      expect(
        visibleDayGlucoseWindow(
          day,
          start.add(const Duration(hours: 1)),
        )!.missing,
        const Duration(hours: 1),
      );
      expect(
        visibleDayGlucoseWindow(dayAt(start, exact, known: false), exact),
        isNull,
      );
    },
  );
  test(
    'calendar-day denominator respects DST and historical partial snapshots do not invent missing future data',
    () {
      for (final date in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
        final end = dayChartClock(date, 0, dayOffset: 1);
        final threshold = Duration(
          microseconds: end.difference(date).inMicroseconds ~/ 10,
        );
        final day = dayAt(date, date.add(threshold));
        final window = visibleDayGlucoseWindow(
          day,
          end.add(const Duration(days: 1)),
        )!;
        expect(window.missing, threshold);
        expect(showDayGlucoseCoverageWarning(day, window), false);
      }
    },
  );
  test(
    'gap intervals match exact measured missing time including the start baseline and trailing gap',
    () {
      Glucose sample(int minute) => Glucose(
        externalId: '$minute',
        source: GlucoseSource.cloud,
        date: start.add(Duration(minutes: minute)),
        sgv: 120,
        direction: 'Flat',
      );
      final window = GlucoseWindowSummary(
        readings: [sample(-2), sample(10)],
        start: start,
        end: start.add(const Duration(minutes: 20)),
      );
      expect(
        window.gaps.map(
          (gap) => (
            gap.start.difference(start).inMinutes,
            gap.end.difference(start).inMinutes,
          ),
        ),
        [(3, 10), (15, 20)],
      );
      expect(
        window.gaps.fold(
          Duration.zero,
          (sum, gap) => sum + gap.end.difference(gap.start),
        ),
        window.missing,
      );
      expect(window.missing, const Duration(minutes: 12));
    },
  );
}
