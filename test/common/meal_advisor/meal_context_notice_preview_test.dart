import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_carbohydrate_notices.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/meal_decision_context_status.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/common/widgets/inline_status_notice.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo/meal_decision_demo_capture.dart';

void main() {
  testWidgets('both carbohydrate types include the window endpoint', (
    tester,
  ) async {
    final now = DateTime(2026, 11, 8, 12);
    final until = now.add(const Duration(hours: 4));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MealDecisionCarbohydrateNotices(
            now: now,
            until: until,
            treatments: [
              Treat(externalId: 'point', createdAt: until, carbs: 13),
              ExtendedCarb(
                externalId: 'interval',
                createdAt: until,
                carbs: 17,
                duration: 60000,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('13 g'), findsOneWidget);
    expect(find.textContaining('17 g'), findsOneWidget);
  });
  testWidgets('context notice gallery uses real shared components', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    LanguageStrings.setSelectedLocale(const Locale('pl'));
    addTearDown(() => LanguageStrings.setSelectedLocale(null));
    final now = DateTime(2026, 11, 8, 12);
    final textTheme = await mealDemoPreviewTextTheme(tester);
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
            child: Builder(
              builder: (context) => ColoredBox(
                color: const Color(0xFF111E25),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        'Kontekst decyzji · przykładowe dane',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      MealDecisionContextStatus(
                        syncedAt: now,
                        glucoseAt: now,
                        iobAt: now,
                        cobAt: now,
                        referenceTime: now,
                      ),
                      const SizedBox(height: 20),
                      InlineStatusNotice(
                        icon: Icons.info_outline,
                        message:
                            '${context.lang.mealTargetTypeMeal} · 90 mg/dl · 11:45–12:30',
                      ),
                      const SizedBox(height: 8),
                      InlineStatusNotice(
                        icon: Icons.info_outline,
                        message:
                            '${context.lang.mealTargetTypeActivity} · 140 mg/dl · 12:00–13:00',
                      ),
                      const SizedBox(height: 8),
                      InlineStatusNotice(
                        icon: Icons.warning_amber_rounded,
                        iconColor: Colors.amber.shade700,
                        message: context.lang
                            .mealDecisionContextPlannedActivity(
                              'Trening',
                              '12:45',
                            ),
                      ),
                      const SizedBox(height: 8),
                      MealDecisionCarbohydrateNotices(
                        now: now,
                        until: now.add(const Duration(hours: 4)),
                        treatments: [
                          Treat(
                            externalId: 'future',
                            createdAt: now.add(const Duration(minutes: 20)),
                            carbs: 15,
                          ),
                          ExtendedCarb(
                            externalId: 'ongoing',
                            createdAt: now.subtract(
                              const Duration(minutes: 30),
                            ),
                            carbs: 24,
                            duration: const Duration(hours: 2).inMilliseconds,
                          ),
                          ExtendedCarb(
                            externalId: 'future-extended',
                            createdAt: now.add(const Duration(minutes: 30)),
                            carbs: 18,
                            duration: const Duration(hours: 1).inMilliseconds,
                          ),
                          Treat(
                            externalId: 'invalid',
                            createdAt: now.add(const Duration(minutes: 10)),
                            carbs: 99,
                            isValid: false,
                          ),
                          Treat(
                            externalId: 'past',
                            createdAt: now.subtract(const Duration(minutes: 1)),
                            carbs: 88,
                          ),
                          ExtendedCarb(
                            externalId: 'ended',
                            createdAt: now.subtract(const Duration(hours: 2)),
                            carbs: 77,
                            duration: 60000,
                          ),
                          Treat(
                            externalId: 'outside',
                            createdAt: now.add(const Duration(hours: 5)),
                            carbs: 66,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12:00'), findsOneWidget);
    expect(find.textContaining('15 g'), findsOneWidget);
    expect(find.textContaining('24 g'), findsOneWidget);
    expect(find.textContaining('18 g'), findsOneWidget);
    for (final excluded in ['99 g', '88 g', '77 g', '66 g']) {
      expect(find.textContaining(excluded), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await captureMealDemo(tester, '07-context-notice-examples');
  });
}
