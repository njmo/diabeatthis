import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/widgets/data_warning_indicator.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_glucose_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 9, 11);
  Glucose reading(int seconds) => Glucose(
    externalId: '$seconds',
    source: GlucoseSource.cloud,
    date: start.add(Duration(seconds: seconds)),
    sgv: 120,
    direction: '',
  );
  GlucosePeriodSummary summary(Iterable<int> seconds) =>
      GlucosePeriodSummary.calculate(
        seconds.map(reading),
        start,
        start.add(const Duration(hours: 6)),
      );
  Future<void> show(WidgetTester tester, GlucosePeriodSummary data) =>
      tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGlucoseCard(title: 'Glikemia', summary: data),
            ),
          ),
        ),
      );

  testWidgets(
    '72 regular readings over six hours do not warn about accumulated one-second jitter',
    (tester) async {
      final data = summary(List.generate(72, (index) => index * 301));
      expect(data.window.readings, hasLength(72));
      expect(data.window.missing, greaterThan(const Duration(minutes: 1)));
      expect(data.hasContinuousReadings, isTrue);
      await show(tester, data);
      expect(find.byType(DataWarningIndicator), findsNothing);
      // Statistical coverage remains conservative; no missing time is fabricated.
      expect(data.coveragePercent, lessThan(100));
    },
  );

  testWidgets(
    'small gaps stay below warning threshold while clustered history still warns',
    (tester) async {
      for (final (index, seconds) in [
        [
          ...List.generate(
            72,
            (index) => index * 300,
          ).where((second) => second != 3600),
          1,
        ],
        [...List.generate(71, (index) => index * 300), 21000],
        List.generate(72, (index) => index),
      ].indexed) {
        final data = summary(seconds);
        expect(seconds, hasLength(72));
        expect(data.hasContinuousReadings, isFalse);
        expect(data.missingReadingCount, [1, 1, 71][index]);
        await show(tester, data);
        expect(
          find.byType(DataWarningIndicator),
          index == 2 ? findsOneWidget : findsNothing,
        );
      }
    },
  );

  testWidgets(
    'a regular stream shifted from the hour boundary has no warning',
    (tester) async {
      final data = summary(List.generate(72, (index) => 120 + index * 300));
      expect(data.window.missing, const Duration(minutes: 2));
      await show(tester, data);
      expect(find.byType(DataWarningIndicator), findsNothing);
    },
  );
}
