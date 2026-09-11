import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meals/common/widgets/glucose_boundary_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 9, 9, 20);
  Glucose sample(int minute, int value) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: start.add(Duration(minutes: minute)),
    sgv: value,
    direction: 'Flat',
    type: GlucoseType.cgm,
  );
  testWidgets(
    'shows actual timestamps even when the last sample is far from the end',
    (tester) async {
      final summary = GlucosePeriodSummary.calculate(
        [sample(-2, 132), sample(20, 170)],
        start,
        start.add(const Duration(minutes: 90)),
      ).window;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: GlucoseBoundaryMetrics(
              summary: summary,
              startLabel: 'Początek posiłku',
            ),
          ),
        ),
      );
      expect(find.text('132 mg/dl'), findsOneWidget);
      expect(find.text('19:58'), findsOneWidget);
      expect(find.text('170 mg/dl'), findsOneWidget);
      expect(find.text('20:20'), findsOneWidget);
      expect(find.text('21:30'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('does not use an old or future sample as the meal baseline', (
    tester,
  ) async {
    final summary = GlucosePeriodSummary.calculate(
      [sample(-6, 120), sample(2, 140)],
      start,
      start.add(const Duration(minutes: 90)),
    ).window;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: GlucoseBoundaryMetrics(
            summary: summary,
            startLabel: 'Początek posiłku',
          ),
        ),
      ),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('140 mg/dl'), findsOneWidget);
    expect(find.text('120 mg/dl'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
