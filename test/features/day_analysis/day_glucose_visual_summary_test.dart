import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/theme/glucose_range_colors.dart';
import 'package:diabeatthis/common/widgets/glucose_range_bar.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_glucose_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 9, 11);
  Glucose reading(int minute, int value) => Glucose(
    externalId: '$minute',
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: '',
  );

  testWidgets(
    'ranges retain observed percentages and show missing time separately',
    (tester) async {
      final summary = GlucosePeriodSummary.calculate(
        [reading(0, 100), reading(5, 200), reading(10, 60)],
        start,
        start.add(const Duration(minutes: 30)),
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGlucoseCard(title: 'Dzień', summary: summary),
            ),
          ),
        ),
      );
      expect(find.text('120 mg/dl'), findsOneWidget);
      expect(find.text('60–200 mg/dl'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(
        find.text('W zakresie 70–180 mg/dl · 33% · 5 min'),
        findsOneWidget,
      );
      expect(find.text('Powyżej 180 mg/dl · 33% · 5 min'), findsOneWidget);
      expect(find.text('Poniżej 70 mg/dl · 33% · 5 min'), findsOneWidget);
      expect(find.text('Brak odczytów · 15 min'), findsOneWidget);
      final bar = find.byType(GlucoseRangeBar);
      final segments = tester
          .widgetList<Expanded>(
            find.descendant(of: bar, matching: find.byType(Expanded)),
          )
          .toList();
      expect(segments.map((segment) => segment.flex), [
        300000,
        300000,
        300000,
        900000,
      ]);
      final colors = tester
          .widgetList<ColoredBox>(
            find.descendant(of: bar, matching: find.byType(ColoredBox)),
          )
          .map((box) => box.color);
      const palette = GlucoseRangeColors(Brightness.light);
      expect(colors, [
        palette.inRange,
        palette.aboveRange,
        palette.belowRange,
        palette.missing,
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty history differs from a failed source and midnight has no invented percentages',
    (tester) async {
      for (final end in [start, start.add(const Duration(hours: 1))]) {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DayGlucoseCard(
                  title: 'Noc',
                  summary: GlucosePeriodSummary.calculate([], start, end),
                ),
              ),
            ),
          ),
        );
        expect(
          find.text('Brak odczytów pozwalających obliczyć czas w zakresach.'),
          findsOneWidget,
        );
        expect(find.textContaining('· — ·'), findsNWidgets(3));
        expect(find.textContaining('100%'), findsNothing);
        expect(
          find.text('Nie udało się pobrać danych. Spróbuj odświeżyć.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        localizedMaterialApp(
          home: const Scaffold(
            body: DayGlucoseCard(title: 'Dzień', summary: null),
          ),
        ),
      );
      expect(
        find.text('Nie udało się pobrać danych. Spróbuj odświeżyć.'),
        findsOneWidget,
      );
      expect(find.byType(GlucoseRangeBar), findsNothing);
    },
  );

  testWidgets(
    'night card remains readable at 320 pixels with large text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Theme(
              data: ThemeData(brightness: brightness),
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: DayGlucoseCard(
                      title: 'Ostatnia noc · 22:00–06:00',
                      summary: GlucosePeriodSummary.calculate(
                        [reading(0, 123)],
                        start,
                        start.add(const Duration(hours: 8)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('123 mg/dl'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
}
