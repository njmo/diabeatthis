import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_analysis_data.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_after_meals_card.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_observation_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'carbs are visible without expanding events, observation explanation uses help',
    (tester) async {
      final start = DateTime(2026, 10, 28, 17);
      final end = start.add(const Duration(hours: 1));
      final analysis = ActivityLogAnalysisData(
        chartStart: start,
        chartEnd: end.add(const Duration(hours: 3)),
        activityStart: start,
        activityEnd: end,
        glucoseReadings: const [],
        deviceStatuses: const [],
        activityTargets: const [],
        preActivityMeals: const [],
        deviceStatusAtStart: null,
        chartTreatments: [
          Treat(
            externalId: 'after',
            createdAt: end.add(const Duration(minutes: 35)),
            carbs: 20,
          ),
          Treat(externalId: 'before', createdAt: start, carbs: 10),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ActivityObservationInfoCard(analysis: analysis),
                  ActivityAfterMealsCard(analysis: analysis),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lang = tester.element(find.byType(ActivityAfterMealsCard)).lang;
      expect(find.text('20 g · 18:35'), findsOneWidget);
      expect(find.text(lang.activityMealAfterOffset('35')), findsOneWidget);
      expect(find.text('10 g · 17:00'), findsNothing);
      expect(find.text('18:00–21:00'), findsOneWidget);
      expect(find.text(lang.activityPostWindow), findsNothing);
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text(lang.activityPostWindow), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
