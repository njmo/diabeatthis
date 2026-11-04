import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/information_button.dart';
import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_details_data.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_glucose_overview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'later reading is on the extended chart with a finish marker and explanation',
    (tester) async {
      final start = DateTime(2026, 10, 28, 17);
      final end = start.add(const Duration(hours: 1));
      final log = ActivityLogDetailsData(
        id: 1,
        activityId: 1,
        activityName: 'Activity',
        percentagePre: 80,
        percentagePost: 80,
        durationMinutes: 60,
        startedAt: start,
        endedAt: end,
        intensity: null,
        notes: null,
        isSynced: false,
        createdAt: start,
        updatedAt: end,
      );
      final analysis = ActivityLogAnalysisData(
        chartStart: start,
        chartEnd: end.add(const Duration(hours: 3)),
        activityStart: start,
        activityEnd: end,
        glucoseReadings: [
          for (final pair in [(0, 183), (55, 91), (64, 66)])
            Glucose(
              externalId: null,
              source: GlucoseSource.cloud,
              date: start.add(Duration(minutes: pair.$1)),
              sgv: pair.$2,
              direction: '',
            ),
        ],
        deviceStatuses: const [],
        chartTreatments: const [],
        activityTargets: const [],
        preActivityMeals: const [],
        deviceStatusAtStart: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActivityGlucoseOverview(analysis: analysis, log: log),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<TimelineAnalysisCharts>(
        find.byType(TimelineAnalysisCharts),
      );
      expect(chart.chartEnd, end.add(const Duration(minutes: 4)));
      expect(chart.glucoseReadings.last.sgv, 66);
      expect(chart.ranges.single.start, end);
      final lang = tester.element(find.byType(ActivityGlucoseOverview)).lang;
      expect(
        find.text(lang.activityPostEndReadingTime('18:04')),
        findsOneWidget,
      );
      expect(find.text(lang.activityDeltaToPostReading), findsOneWidget);
      final info = find.byType(InformationButton).first;
      await tester.ensureVisible(info);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(
        find.text(
          lang.activityPostEndReadingExplanation('18:00', '18:04', '4 min'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
