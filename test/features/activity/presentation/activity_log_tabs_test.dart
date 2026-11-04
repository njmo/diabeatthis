import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_details_data.dart';
import 'package:diabeatthis/features/activity/presentation/models/activity_log_page_state.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  for (final locale in ['pl', 'en']) {
    testWidgets('activity tabs render at narrow width with enlarged text: $locale', (tester) async {
      await initializeDateFormatting(locale);
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final start = DateTime(2026, 11, 3, 15, 23);
      final end = start.add(const Duration(minutes: 45));
      final log = ActivityLogDetailsData(id: 1, activityId: 1,
        activityName: 'Swimming', percentagePre: 80, percentagePost: 80,
        durationMinutes: 45, startedAt: start, endedAt: end,
        intensity: 'high', notes: 'Session notes', summarizedAt: end,
        isSynced: false, createdAt: start, updatedAt: end);
      final analysis = ActivityLogAnalysisData(
        chartStart: start.subtract(const Duration(minutes: 30)),
        chartEnd: end.add(const Duration(hours: 3)),
        activityStart: start, activityEnd: end,
        glucoseReadings: [for (var i = 0; i <= 45; i += 5)
          Glucose(externalId: null, source: GlucoseSource.cloud,
            date: start.add(Duration(minutes: i)), sgv: 100 + i, direction: '')],
        deviceStatuses: const [], chartTreatments: const [],
        activityTargets: const [], preActivityMeals: const [], deviceStatusAtStart: null,
      );
      await tester.pumpWidget(MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(body: ActivityLogBody(
          state: ActivityLogPageState(data: log, analysis: AsyncData(analysis)),
          onTimestampSelected: (_) {},
        )),
      ));
      await tester.pumpAndSettle();
      final tabs = tester.widget<SwipeableCards>(find.byType(SwipeableCards));
      expect(tabs.labels.length, 5);
      expect(tester.takeException(), isNull);
      for (var index = 1; index < 5; index++) {
        tabs.controller.animateTo(index);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Tab $index');
      }
      expect(find.text('Session notes'), findsOneWidget);
    });
  }
}
