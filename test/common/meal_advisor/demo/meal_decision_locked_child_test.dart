import 'dart:async';

import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/child_meal_decision_demo_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:diabeatthis/common/widgets/application_backdrop.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_option.dart';
import 'package:diabeatthis/common/widgets/timeline_analysis_charts.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'meal_decision_demo_capture.dart';

void main() {
  for (final answer in MealDecisionDemoAnswer.values) {
    testWidgets(
      'child cannot dismiss a sent request and follows the concrete $answer action',
      (tester) async {
        LanguageStrings.setSelectedLocale(const Locale('en'));
        addTearDown(() => LanguageStrings.setSelectedLocale(null));
        tester.view.physicalSize = const Size(420, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final delivery = Completer<void>();
        final container = ProviderContainer(
          overrides: [
            googleAccountProvider.overrideWith((ref) => Stream.value(null)),
            mealDecisionDemoDelayProvider.overrideWithValue(
              () => delivery.future,
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No real writes'),
            ),
          ],
        );
        addTearDown(container.dispose);
        final textTheme = await mealDemoPreviewTextTheme(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: mealDemoPreviewBoundary,
            child: UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: applicationThemeData(
                  brightness: Brightness.dark,
                  textTheme: textTheme,
                ),
                builder: (context, child) => ApplicationBackdrop(child: child!),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showChildMealDecisionDemo(
                        context,
                        requestKey: 'locked',
                        mealName: 'Lunch',
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Simulate sending request'));
        await tester.pump();
        expect(find.byTooltip('Close'), findsNothing);
        expect(find.text('Close'), findsNothing);
        expect(find.text('Reject response'), findsNothing);
        expect(find.text('Cancel request'), findsNothing);
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.drag(find.byType(BottomSheet), const Offset(0, 400));
        await tester.pump();
        expect(find.byType(ChildMealDecisionDemoSheet), findsOneWidget);
        delivery.complete();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ChildMealDecisionDemoSheet), findsOneWidget);
        if (answer == MealDecisionDemoAnswer.insulinThenWait) {
          await captureMealDemo(tester, '01-child-waiting');
        }
        await tester.tap(find.text('Simulate caregiver response'));
        await tester.pumpAndSettle();
        if (answer == MealDecisionDemoAnswer.insulinThenWait) {
          await captureMealDemo(tester, '05-caregiver-context');
          await tester.ensureVisible(find.byType(TimelineAnalysisCharts).first);
          await tester.pumpAndSettle();
          await captureMealDemo(tester, '06-caregiver-charts');
        }
        final proceed = find.text('Continue to decision');
        await tester.ensureVisible(proceed);
        await tester.tap(proceed);
        await tester.pumpAndSettle();
        expect(find.byType(ManualMealDecisionOption), findsNWidgets(4));
        final selected = find.text(
          answer.decision == null
              ? 'Defer the meal'
              : mealDecisionLabel(answer.decision!),
        );
        await tester.ensureVisible(selected);
        await tester.tap(selected);
        await tester.pumpAndSettle();
        if (answer == MealDecisionDemoAnswer.insulinThenWait) {
          await tester.enterText(find.byType(TextFormField).first, '10');
        }
        if (answer == MealDecisionDemoAnswer.insulinThenWait) {
          await captureMealDemo(tester, '02-caregiver-reply');
        }
        if (answer == MealDecisionDemoAnswer.deferMeal) {
          expect(
            tester
                .widget<TextFormField>(find.byType(TextFormField).first)
                .controller!
                .text,
            '45',
          );
          final target = find.byType(SwitchListTile);
          await tester.ensureVisible(target);
          await tester.tap(target);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Send to child · demo'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        if (answer == MealDecisionDemoAnswer.insulinThenWait) {
          await captureMealDemo(tester, '03-child-response');
        }
        final response = container.read(
          mealDecisionDemoControllerProvider,
        )['locked']!;
        if (answer == MealDecisionDemoAnswer.deferMeal) {
          expect(response.waitMinutes, 45);
          expect(response.suggestMealTarget, isTrue);
          await captureMealDemo(tester, '04-child-deferral');
        }
        const action = 'Accept';
        expect(find.byTooltip('Close'), findsNothing);
        expect(find.text('Close'), findsNothing);
        expect(find.text('Lunch'), findsOneWidget);
        expect(
          find.text(DateFormat.Hm().format(response.snapshot.capturedAt)),
          findsOneWidget,
        );
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ChildMealDecisionDemoSheet), findsOneWidget);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(
          container.read(mealDecisionDemoControllerProvider)['locked']!.status,
          MealDecisionDemoStatus.accepted,
        );
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(ChildMealDecisionDemoSheet), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
