import 'dart:ui' as ui;

import 'package:diabeatthis/common/presentation/day/day_chart_time.dart';
import 'package:diabeatthis/common/presentation/day/day_glucose_chart.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'isolated daytime low remains painted in the default spline style',
    (tester) async {
      final start = DateTime.utc(2026, 11, 17);
      final readings = [
        for (final (hour, sgv) in [(6, 60), (12, 120)])
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            date: start.add(Duration(hours: hour)),
            sgv: sgv,
            direction: '',
          ),
      ];
      final recorder = ui.PictureRecorder();
      DayGlucosePainter(
        readings: readings,
        events: [],
        dayStart: start,
        asOf: start.add(const Duration(hours: 13)),
        style: DayChartStyle.smoothSpline,
        isDark: false,
      ).paint(ui.Canvas(recorder), const ui.Size(400, 200));
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(400, 200);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final offset = (164 * 400 + 96) * 4;
        expect(
          [
            for (var channel = 0; channel < 4; channel++)
              pixels.getUint8(offset + channel),
          ],
          [239, 68, 68, 255],
        );
        image.dispose();
      });
      picture.dispose();
    },
  );
  test(
    'chart gaps split immediately after the five-minute observation limit',
    () {
      final start = DateTime.utc(2026, 11, 17);
      final readings = [
        for (final offset in [0, 300, 601, 901])
          Glucose(
            externalId: null,
            source: GlucoseSource.cloud,
            date: start.add(Duration(seconds: offset)),
            sgv: 120,
            direction: '',
          ),
      ];
      expect(dayChartSegments(readings).map((segment) => segment.length), [
        2,
        2,
      ]);
    },
  );

  final warsaw =
      DateTime(2026, 1, 1).timeZoneOffset == const Duration(hours: 1) &&
      DateTime(2026, 7, 1).timeZoneOffset == const Duration(hours: 2);
  for (final (month, day, dayHours, nightHours) in [
    (3, 29, 23, 7),
    (10, 25, 25, 9),
  ]) {
    test(
      'calendar charts retain DST boundaries for $month/$day',
      () {
        final start = DateTime(2026, month, day);
        final end = dayChartClock(start, 24);
        expect(end.difference(start), Duration(hours: dayHours));
        expect(
          dayChartFraction(dayChartClock(start, 4), start, end),
          closeTo((dayHours == 23 ? 3 : 5) / dayHours, 0.000001),
        );
        final nightStart = dayChartClock(start, 22, dayOffset: -1);
        final nightEnd = dayChartClock(start, 6);
        expect(nightEnd.difference(nightStart), Duration(hours: nightHours));
        expect(
          dayChartFraction(
            nightEnd.subtract(const Duration(minutes: 30)),
            nightStart,
            nightEnd,
          ),
          lessThan(1),
        );
        expect(dayChartFraction(nightEnd, nightStart, nightEnd), 1);
        final ticks = dayNightChartTicks(nightStart, nightEnd);
        expect(
          ticks.map((tick) => tick.$2),
          month == 3
              ? ['22:00', '00:00', '04:00', '06:00']
              : ['22:00', '00:00', '02:00', '04:00', '06:00'],
        );
        for (final (time, label) in ticks) {
          expect(label, '${time.hour.toString().padLeft(2, '0')}:00');
        }
      },
      skip: warsaw
          ? false
          : 'Run with TZ=Europe/Warsaw to verify DST boundaries',
    );
  }
}
