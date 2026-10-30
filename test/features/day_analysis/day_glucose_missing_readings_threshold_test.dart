import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/widgets/data_warning_indicator.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_glucose_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 10, 30);
  GlucosePeriodSummary summary(int missing) => GlucosePeriodSummary.calculate(
    List.generate(20, (index) => index)
        .where((index) => index < 3 || index >= 3 + missing)
        .map(
          (index) => Glucose(
            externalId: '$index',
            source: GlucoseSource.cloud,
            date: start.add(Duration(minutes: index * 5)),
            sgv: 120,
            direction: '',
          ),
        ),
    start,
    start.add(const Duration(minutes: 100)),
  );

  for (final missing in [0, 1, 2, 3]) {
    testWidgets('warns at ten percent missing readings: $missing of 20', (
      tester,
    ) async {
      final data = summary(missing);
      expect(data.expectedReadingCount, 20);
      expect(data.missingReadingCount, missing);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DayGlucoseCard(title: 'CGM', summary: data),
            ),
          ),
        ),
      );
      expect(
        find.byType(DataWarningIndicator),
        missing >= 2 ? findsOneWidget : findsNothing,
      );
      if (missing == 2) {
        expect(
          tester
              .widget<DataWarningIndicator>(find.byType(DataWarningIndicator))
              .message,
          'Brakujące odczyty CGM: 2 z 20 (10,0%).',
        );
      }
    });
  }

  test('empty history reports all expected readings missing', () {
    final data = GlucosePeriodSummary.calculate(
      [],
      start,
      start.add(const Duration(hours: 1)),
    );
    expect(data.expectedReadingCount, 12);
    expect(data.missingReadingCount, 12);
  });
  test(
    'a fresh baseline covers a short window before the next sample is due',
    () {
      final data = GlucosePeriodSummary.calculate(
        [
          Glucose(
            externalId: 'baseline',
            source: GlucoseSource.cloud,
            date: start.subtract(const Duration(minutes: 2)),
            sgv: 120,
            direction: '',
          ),
        ],
        start,
        start.add(const Duration(minutes: 1)),
      );
      expect(data.missingReadingCount, 0);
    },
  );
}
