import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/analysis_metric.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_amount_breakdown.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_archived_glucose_ranges.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_insulin_breakdown.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'archived basal distinguishes unobserved history from recorded zero without changing the snapshot',
    (tester) async {
      for (final coverage in [null, 0, 50, 100]) {
        final time = DateTime(2026, 9, 15);
        final snapshot = DaySummarySnapshot(
          dayKey: '2026-09-15',
          asOf: time,
          builtAt: time,
          utcOffsetMinutes: 120,
          metrics: {
            DaySummaryMetric.basalCoveragePercent: coverage,
            DaySummaryMetric.nightBasalCoveragePercent: coverage,
            DaySummaryMetric.basalUnits: 0,
            DaySummaryMetric.nightBasalUnits: 0,
            DaySummaryMetric.bolusUnits: 6,
            DaySummaryMetric.smbUnits: 2,
            DaySummaryMetric.totalInsulinUnits: 6,
          },
          limitations: [],
          review: [],
        );
        final stored = snapshot.encode();
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DaySummaryFacts(snapshot: snapshot),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final lang = tester.element(find.byType(DaySummaryFacts)).lang;
        final known = coverage != null && coverage > 0;
        expect(
          tester
              .widget<DayInsulinBreakdown>(find.byType(DayInsulinBreakdown))
              .basal,
          known ? 0 : null,
        );
        final metrics = tester.widgetList<AnalysisMetric>(
          find.byType(AnalysisMetric),
        );
        expect(
          metrics
              .singleWhere(
                (m) => m.label == lang.daySummaryMetricTotalInsulinUnits,
              )
              .value,
          known ? '6,0' : lang.beforeMealUnavailable,
        );
        expect(
          metrics
              .singleWhere(
                (m) => m.label == lang.daySummaryMetricNightBasalUnits,
              )
              .value,
          known ? '0,0' : lang.beforeMealUnavailable,
        );
        expect(snapshot.encode(), stored);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'archived CGM allocates the same window fraction to missing history as the live bar',
    (tester) async {
      for (final coverage in [0.0, 50.0, 100.0, null]) {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: DayArchivedGlucoseRanges(
                coverage: coverage,
                inRange: coverage == 0 ? null : 50,
                aboveRange: coverage == 0 ? null : 20,
                belowRange: coverage == 0 ? null : 30,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<DayAmountBreakdown>(
          find.byType(DayAmountBreakdown),
        );
        expect(
          chart.segments.map((s) => s.amount),
          coverage == null
              ? [null, null, null, null]
              : [
                  coverage * .5,
                  coverage * .2,
                  coverage * .3,
                  if (coverage < 100) 100 - coverage,
                ],
        );
        final segments = tester
            .widgetList<Expanded>(find.byType(Expanded))
            .toList();
        if (coverage == null) {
          expect(segments, isEmpty);
        } else if (coverage == 0) {
          expect(segments, hasLength(1));
          expect(chart.segments.last.amount, 100);
        } else if (coverage == 50) {
          final total = segments.fold(0, (sum, s) => sum + s.flex);
          expect(segments.last.flex / total, .5);
          expect(find.textContaining('50,0%'), findsWidgets);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
}
