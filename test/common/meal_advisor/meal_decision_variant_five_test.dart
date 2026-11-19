import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/context/meal_decision_activity_context.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_activity_card.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_activity_glucose_preview.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_context_status.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/meal_decision_preview_capture.dart';

void main() {
  testWidgets(
    'recorded mini chart filters invalid samples and preserves gaps',
    (tester) async {
      final start = DateTime(2026, 11, 8, 10);
      Glucose sample(
        int minutes,
        int value, {
        GlucoseType type = GlucoseType.cgm,
      }) => Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: start.add(Duration(minutes: minutes)),
        sgv: value,
        direction: 'Flat',
        type: type,
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealDecisionActivityGlucoseChart(
              start: start,
              end: start.add(const Duration(minutes: 45)),
              readings: [
                sample(-5, 90),
                sample(0, 120),
                sample(5, 115),
                sample(30, 110),
                sample(35, 0),
                sample(40, 109, type: GlucoseType.finger),
                sample(50, 105),
              ],
            ),
          ),
        ),
      );
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final spots = chart.data.lineBarsData.single.spots;
      expect(spots.where((s) => !s.isNull()).map((s) => s.x), [0, 5, 30]);
      expect(spots.where((s) => s.isNull()), hasLength(1));
      expect(chart.data.maxX, 45);
    },
  );

  for (final baseline in [90, 170]) {
    testWidgets(
      'mini chart retains an anchored scale at $baseline including single samples',
      (tester) async {
        final start = DateTime(2026, 11, 8, 10);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: MealDecisionActivityGlucoseChart(
                start: start,
                end: start.add(const Duration(minutes: 45)),
                readings: [
                  Glucose(
                    externalId: null,
                    source: GlucoseSource.cloud,
                    date: start,
                    sgv: baseline,
                    direction: 'Flat',
                  ),
                ],
              ),
            ),
          ),
        );
        final chart = tester.widget<LineChart>(find.byType(LineChart));
        expect(chart.data.minY, 0);
        expect(chart.data.maxY, 250);
        expect(chart.data.lineBarsData.single.spots.single.y, baseline);
        expect(find.textContaining('mg/dl'), findsOneWidget);
        expect(find.text('70'), findsOneWidget);
        expect(find.text('180'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'variant five distinguishes planned completed and ongoing sessions',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('pl'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 11, 8, 12);
      final start = DateTime(2026, 11, 8, 10, 15);
      final end = start.add(const Duration(minutes: 45));
      final textTheme = await mealDemoPreviewTextTheme(tester);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: applicationThemeData(
            brightness: Brightness.dark,
            textTheme: textTheme,
          ),
          home: Scaffold(
            body: RepaintBoundary(
              key: mealDemoPreviewBoundary,
              child: ColoredBox(
                color: const Color(0xFF111E25),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Kontekst wokół posiłku'),
                      const SizedBox(height: 12),
                      MealDecisionContextStatus(
                        syncedAt: now,
                        glucoseAt: now,
                        iobAt: now,
                        cobAt: now,
                        referenceTime: now,
                      ),
                      const SizedBox(height: 12),
                      MealDecisionActivityCard(
                        activity: MealDecisionActivityContext(
                          kind: 'activities',
                          id: 1,
                          name: 'Piłka nożna',
                          at: now.add(const Duration(minutes: 45)),
                          planned: true,
                        ),
                        openRecord: () => opened++,
                      ),
                      const SizedBox(height: 12),
                      MealDecisionActivityCard(
                        activity: MealDecisionActivityContext(
                          kind: 'activityLogs',
                          id: 2,
                          name: 'Jazda na rowerze',
                          at: start,
                          endedAt: end,
                          planned: false,
                        ),
                        openRecord: () => opened++,
                        glucoseHistory: MealDecisionActivityGlucoseChart(
                          start: start,
                          end: end,
                          readings: [
                            for (var i = 0; i <= 9; i++)
                              Glucose(
                                externalId: null,
                                source: GlucoseSource.cloud,
                                date: start.add(Duration(minutes: 5 * i)),
                                sgv: 130 - i * 3,
                                direction: 'Flat',
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      MealDecisionActivityCard(
                        activity: MealDecisionActivityContext(
                          kind: 'activityLogs',
                          id: 3,
                          name: 'Spacer',
                          at: now,
                          planned: false,
                        ),
                        openRecord: () => opened++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Trening zaplanowany'), findsOneWidget);
      expect(find.text('Trening zakończony'), findsOneWidget);
      expect(find.text('Trening w trakcie'), findsOneWidget);
      expect(find.byType(LineChart), findsOneWidget);
      await tester.tap(find.text('Piłka nożna'));
      await tester.tap(find.text('Jazda na rowerze'));
      expect(opened, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      await captureMealDemo(tester, '08-context-variant-five');
    },
  );
}
