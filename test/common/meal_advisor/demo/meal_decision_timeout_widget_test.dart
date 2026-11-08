import 'package:clock/clock.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_picker_field.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'child timer invalidates the request and the caregiver sees an outcome only after it exists',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('en'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      var now = DateTime(2026, 11, 8, 12);
      await withClock(Clock(() => now), () async {
        final container = ProviderContainer(
          overrides: [
            googleAccountProvider.overrideWith((ref) => Stream.value(null)),
            mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
            mealDecisionPreferencesProvider.overrideWithValue(
              const MealDecisionPreferences(
                timeoutFallback: MealDecisionTimeoutFallback.manual,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          mealDecisionDemoControllerProvider.notifier,
        );
        await controller.send('meal', 'Lunch');
        final id = container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .id;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showCaregiverMealDecisionDemo(
                      context,
                      requestKey: 'meal',
                      requestId: id,
                      caregiverName: 'Anna',
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Close'), findsNothing);
        await tester.tapAt(const Offset(3, 3));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('1/2 · Context and meal'), findsOneWidget);
        now = now.add(const Duration(minutes: 5));
        await tester.pump(const Duration(minutes: 5));
        await tester.pumpAndSettle();
        expect(
          container.read(mealDecisionDemoControllerProvider)['meal']!.status,
          MealDecisionDemoStatus.timedOut,
        );
        expect(
          find.text('Time expired. The child is making their own decision.'),
          findsOneWidget,
        );
        expect(
          controller.respond(
            'meal',
            id,
            answer: MealDecisionDemoAnswer.insulinAndEat,
            minutes: 0,
            caregiverName: 'Anna',
          ),
          isFalse,
        );
        final chosen = MealAdvice(
          MealDecisionDemoAnswer.eatThenInsulin.decision,
          null,
          source: 'manualDemo',
        );
        expect(controller.completeFallback('meal', id, chosen), isTrue);
        await tester.pumpAndSettle();
        expect(find.textContaining('Manual choice · demo'), findsOneWidget);
        expect(find.textContaining('Food first, then insulin'), findsOneWidget);
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  for (final method in MealDecisionTimeoutFallback.values) {
    testWidgets(
      'child confirms the configured timeout fallback without real writes: $method',
      (tester) async {
        LanguageStrings.setSelectedLocale(const Locale('en'));
        addTearDown(() => LanguageStrings.setSelectedLocale(null));
        var now = DateTime(2026, 11, 8, 12);
        await withClock(Clock(() => now), () async {
          final container = ProviderContainer(
            overrides: [
              googleAccountProvider.overrideWith((ref) => Stream.value(null)),
              databaseProvider.overrideWith(
                (ref) => throw StateError('No real fallback database access'),
              ),
              mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
              mealDecisionPreferencesProvider.overrideWithValue(
                MealDecisionPreferences(timeoutFallback: method),
              ),
            ],
          );
          addTearDown(container.dispose);
          final controller = container.read(
            mealDecisionDemoControllerProvider.notifier,
          );
          await controller.send('child-timeout', 'Lunch');
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showChildMealDecisionDemo(
                        context,
                        requestKey: 'child-timeout',
                        mealName: 'Lunch',
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          now = now.add(const Duration(minutes: 5));
          await tester.pump(const Duration(minutes: 5));
          await tester.pumpAndSettle();
          expect(find.text('No caregiver reply in time'), findsOneWidget);
          expect(
            container
                .read(mealDecisionDemoControllerProvider)['child-timeout']!
                .fallbackAdvice,
            isNull,
          );
          if (method == MealDecisionTimeoutFallback.manual) {
            await tester.tap(find.text('Choose manually'));
            await tester.pumpAndSettle();
            await tester.tap(find.byType(ManualMealDecisionPickerField));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Food first, then insulin'));
            await tester.pumpAndSettle();
            await tester.tap(
              find.text(
                lookupAppLocalizations(const Locale('en')).addIngredientNext,
              ),
            );
          } else {
            await tester.tap(find.text('Open Meal Advisor · demo'));
            await tester.pumpAndSettle();
            expect(
              find.textContaining('This mock does not run the real advisor'),
              findsOneWidget,
            );
            await tester.tap(find.text('Accept'));
          }
          await tester.pumpAndSettle();
          final choice = container
              .read(mealDecisionDemoControllerProvider)['child-timeout']!
              .fallbackAdvice!;
          expect(
            choice.source,
            method == MealDecisionTimeoutFallback.manual
                ? 'manualDemo'
                : 'mealAdvisorDemo',
          );
          expect(
            choice.decision,
            method == MealDecisionTimeoutFallback.manual
                ? MealDecisionDemoAnswer.eatThenInsulin.decision
                : MealDecisionDemoAnswer.insulinAndEat.decision,
          );
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      },
    );
  }
}
