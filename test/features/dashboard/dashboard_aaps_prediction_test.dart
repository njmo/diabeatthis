import 'dart:convert';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/dashboard/glucose_freshness_provider.dart';
import 'package:diabeatthis/core/domain/model/aaps_prediction_snapshot.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/compact_loop_glucose_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  String prediction(DateTime at, List<double> values) =>
      jsonEncode(AapsPredictionSnapshot(at, {'IOB': values}).toJson());

  testWidgets(
    'forecast legend and future area expire at ten minutes without a clock tick',
    (tester) async {
      var clockNow = now;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardWallClockProvider.overrideWithValue(() => clockNow),
            timeNowProvider.overrideWith((ref) => Stream.value(now)),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CompactLoopGlucoseChart(
                readings: [
                  Glucose(
                    externalId: 'sample',
                    source: GlucoseSource.aaps,
                    date: now,
                    sgv: 97,
                    direction: 'Flat',
                  ),
                ],
                aapsPredictionsJson: prediction(
                  now.subtract(const Duration(minutes: 9, seconds: 59)),
                  [97, 100, 105, 110],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('aaps-prediction-legend')),
        findsOneWidget,
      );
      expect(find.text('━ IOB'), findsOneWidget);
      expect(find.text('━ COB'), findsNothing);
      expect(find.text('+1h'), findsOneWidget);
      expect(find.text('+2h'), findsOneWidget);
      clockNow = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('aaps-prediction-legend')),
        findsNothing,
      );
      expect(find.text('+1h'), findsNothing);
      expect(find.text('+2h'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'actual AAPS forecast needs fresh glucose and a recent nonfuture model',
    () {
      final recent = prediction(now.subtract(const Duration(minutes: 2)), [
        97,
        100,
        105,
      ]);
      expect(
        dashboardAapsPrediction(recent, now, stale: false)!.series['IOB'],
        [97, 100, 105],
      );
      expect(dashboardAapsPrediction(recent, now, stale: true), isNull);
      expect(
        dashboardAapsPrediction(
          prediction(now.add(const Duration(seconds: 1)), [97, 100]),
          now,
          stale: false,
        ),
        isNull,
      );
      expect(
        dashboardAapsPrediction(
          prediction(now.subtract(const Duration(minutes: 10)), [
            97,
            100,
            105,
            110,
          ]),
          now,
          stale: false,
        ),
        isNull,
      );
    },
  );

  test(
    'missing, malformed and exhausted predictions never invent future values',
    () {
      for (final encoded in [
        null,
        '{}',
        prediction(now.subtract(const Duration(minutes: 6)), [97, 100]),
      ]) {
        expect(dashboardAapsPrediction(encoded, now, stale: false), isNull);
      }
    },
  );
}
