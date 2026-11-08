import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/caregiver_meal_decision_demo_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/child_meal_decision_demo_action.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/common/widgets/application_backdrop.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_decision_demo_capture.dart';

void main() {
  setUp(() => LanguageStrings.setSelectedLocale(const Locale('en')));
  tearDown(() => LanguageStrings.setSelectedLocale(null));
  for (final requiresWait in [true, false]) {
    testWidgets(
      'child follows a concrete response without dismissal or real writes: waitsAfterInsulin=$requiresWait',
      (tester) async {
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [
            googleAccountProvider.overrideWith((ref) => Stream.value(null)),
            mealDecisionPreferencesProvider.overrideWithValue(
              const MealDecisionPreferences(
                method: MealDecisionMethod.caregiver,
              ),
            ),
            mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
            databaseProvider.overrideWith(
              (ref) => throw StateError('Demo must never access the database'),
            ),
            authenticatedFamilyTransportProvider.overrideWith(
              (ref) => throw StateError('Demo must never access Firebase'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final results = <Object?>[];
        final textTheme = await mealDemoPreviewTextTheme(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: mealDemoPreviewBoundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: applicationThemeData(
                  brightness: Brightness.dark,
                  textTheme: textTheme,
                ),
                builder: (context, child) => ApplicationBackdrop(child: child!),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        TextButton(
                          onPressed: () async {
                            await showChildMealDecisionDemo(
                              context,
                              requestKey: 'patient:7',
                              mealName: 'Lunch',
                            );
                            results.add(null);
                          },
                          child: const Text('Open meal'),
                        ),
                        const ChildMealDecisionDemoAction(
                          mealId: 7,
                          mealName: 'Lunch',
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
        await tester.tap(find.text('Open meal'));
        await tester.pumpAndSettle();
        expect(find.text('Lunch'), findsOneWidget);
        expect(find.textContaining('Sample values'), findsNothing);
        await tester.tap(find.text('Simulate sending request'));
        await tester.pumpAndSettle();
        expect(find.text('Waiting for caregiver').last, findsOneWidget);
        if (requiresWait) await captureMealDemo(tester, '01-child-waiting');
        expect(find.byTooltip('Close'), findsNothing);
        expect(find.text('Reject response'), findsNothing);
        await tester.tapAt(const Offset(5, 5));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(results, isEmpty);
        expect(find.text('Waiting for caregiver').last, findsOneWidget);
        await tester.tap(find.text('Simulate caregiver response'));
        await tester.pumpAndSettle();
        final proceed = find.text('Continue to decision');
        await tester.ensureVisible(proceed);
        await tester.tap(proceed);
        await tester.pumpAndSettle();
        if (requiresWait) await captureMealDemo(tester, '02-caregiver-reply');
        if (requiresWait) {
          final choice = find.text('Insulin, wait, eat');
          await tester.ensureVisible(choice);
          await tester.tap(choice);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextFormField).first, '0');
          await tester.tap(find.text('Send to child · demo'));
          await tester.pumpAndSettle();
          expect(find.text('Enter a number from 1 to 180.'), findsOneWidget);
          await tester.enterText(find.byType(TextFormField).first, '10');
        }
        await tester.tap(find.text('Send to child · demo'));
        await tester.pumpAndSettle();
        expect(find.byType(CaregiverMealDecisionDemoSheet), findsOneWidget);
        expect(find.textContaining('Decision sent'), findsOneWidget);
        await tester.tap(find.byTooltip('Close').last);
        await tester.pumpAndSettle();
        expect(find.text('Caregiver response received').last, findsOneWidget);
        expect(
          find.text('Message from Anna · caregiver (demo)'),
          findsOneWidget,
        );
        if (requiresWait) await captureMealDemo(tester, '03-child-response');
        expect(find.byTooltip('Close'), findsNothing);
        const action = 'Accept';
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
          container
              .read(mealDecisionDemoControllerProvider)['patient:7']!
              .status,
          MealDecisionDemoStatus.accepted,
        );
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(results, [null]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
