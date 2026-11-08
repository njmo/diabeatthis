import 'dart:ui' as ui;

import 'package:diabeatthis/common/presentation/charts/glucose_chart_timeline.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/mini_glucose_chart.dart';
import 'package:flutter_test/flutter_test.dart';

Glucose reading(int minutes) => Glucose(
  externalId: '$minutes',
  source: GlucoseSource.cloud,
  date: DateTime(2026, 11, 8, 19, minutes),
  sgv: 100,
  direction: 'Flat',
);

void main() {
  test(
    'uses elapsed time rather than equal spacing and splits missing readings',
    () {
      final timeline = GlucoseChartTimeline([
        reading(20),
        reading(0),
        reading(5),
        reading(15),
      ]);
      expect(timeline.values.map((g) => g.date.minute), [0, 5, 15, 20]);
      expect(timeline.fractionAt(reading(5).date), .25);
      expect(timeline.fractionAt(reading(15).date), .75);
      expect(timeline.segments.map((s) => s.length), [2, 2]);
    },
  );

  test('tolerates six minutes and keeps isolated readings visible', () {
    final timeline = GlucoseChartTimeline([
      reading(0),
      reading(6),
      reading(13),
    ]);
    expect(timeline.segments.map((s) => s.length), [2, 1]);
  });

  test('deduplicates timestamps before retaining the latest ten readings', () {
    final timeline = GlucoseChartTimeline([
      for (var i = 0; i < 12; i++) reading(i * 5),
      reading(55),
    ]);
    expect(timeline.values.length, 10);
    expect(timeline.values.first.date.minute, 10);
    expect(timeline.values.last.date.minute, 55);
    expect(timeline.segments.length, 1);
  });

  test('empty and single-point geometry remains finite', () {
    expect(GlucoseChartTimeline([]).fractionAt(DateTime(2026)), 0);
    expect(GlucoseChartTimeline([reading(0)]).fractionAt(reading(0).date), 0);
  });

  testWidgets('painter distinguishes missing data with a dashed connector', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    MiniGlucoseChartPainter([
      reading(0),
      reading(5),
      reading(15),
      reading(20),
    ]).paint(ui.Canvas(recorder), const ui.Size(200, 100));
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(200, 100)))!;
    final bytes = await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    bool columnHasInk(int x) => [
      for (var y = 0; y < 100; y++) bytes!.getUint8((y * 200 + x) * 4 + 3),
    ].any((alpha) => alpha > 0);
    expect(columnHasInk(25), isTrue);
    final gapColumns = [for (var x = 60; x < 140; x++) columnHasInk(x)];
    expect(gapColumns, contains(true));
    expect(gapColumns, contains(false));
    expect(columnHasInk(175), isTrue);
    image.dispose();
    picture.dispose();
  });
  testWidgets('smoothed curve below the low threshold stays red', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final values = [reading(0), reading(5), reading(10), reading(15)];
    final samples = [
      values[0].copyWith(sgv: 60),
      values[1].copyWith(sgv: 60),
      values[2].copyWith(sgv: 180),
      values[3].copyWith(sgv: 180),
    ];
    MiniGlucoseChartPainter(
      samples,
    ).paint(ui.Canvas(recorder), const ui.Size(600, 300));
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(600, 300)))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    // This data scales from 0 to 200; inspect safely below the 70 mg/dl line.
    final lowY = 300 * .18 + 300 * .64 * (1 - 70 / 200);
    var redPixels = 0;
    for (var y = lowY.ceil() + 2; y < 300; y++) {
      for (var x = 0; x < 600; x++) {
        final offset = (y * 600 + x) * 4;
        if (bytes.getUint8(offset + 3) < 100) continue;
        final red = bytes.getUint8(offset);
        final green = bytes.getUint8(offset + 1);
        expect(green > red + 30, isFalse);
        if (red > green + 30) redPixels++;
      }
    }
    expect(redPixels, greaterThan(0));
    image.dispose();
    picture.dispose();
  });
}
