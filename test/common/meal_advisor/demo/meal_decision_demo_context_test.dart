import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_decision_demo_controller_test.dart' show demoContainer;

void main() {
  testWidgets(
    'context navigation preserves a draft and lifecycle tracks only the owning caregiver',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('en'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = demoContainer();
      var containerDisposed = false;
      addTearDown(() {
        if (!containerDisposed) container.dispose();
      });
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      await controller.send('meal', 'Lunch');
      final id = container.read(mealDecisionDemoControllerProvider)['meal']!.id;
      final showLauncher = ValueNotifier(true);
      addTearDown(showLauncher.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: showLauncher,
                builder: (context, visible, child) => visible
                    ? Builder(
                        builder: (context) => TextButton(
                          onPressed: () => showCaregiverMealDecisionDemo(
                            context,
                            requestKey: 'meal',
                            requestId: id,
                            caregiverName: 'Anna',
                          ),
                          child: const Text('Open'),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isTrue,
      );
      expect(find.text('1/2 · Context and meal'), findsOneWidget);
      final mealLink = find.widgetWithText(ListTile, 'Lunch');
      await tester.ensureVisible(mealLink);
      await tester.tap(mealLink);
      await tester.pumpAndSettle();
      expect(find.text('Meal and similar history · demo'), findsOneWidget);
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isTrue,
      );
      await tester.ensureVisible(find.byType(ExpansionTile).first);
      await tester.tap(find.byType(ExpansionTile).first);
      await tester.pumpAndSettle();
      expect(
        find.text('Glucose during 2 hours after the meal · sample'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();
      final proceed = find.text('Continue to decision');
      await tester.ensureVisible(proceed);
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.stage,
        MealDecisionDemoStage.decision,
      );
      await tester.enterText(find.byType(TextFormField).last, 'Lunch is ready');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.stage,
        MealDecisionDemoStage.context,
      );
      await tester.ensureVisible(find.text('Continue to decision'));
      await tester.tap(find.text('Continue to decision'));
      await tester.pumpAndSettle();
      expect(find.text('Lunch is ready'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isFalse,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isTrue,
      );
      showLauncher.value = false;
      await tester.pump();
      expect(find.byTooltip('Close'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('2/2 · Decision and message'), findsOneWidget);
      await tester.tap(find.text('Transfer to another caregiver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adam'));
      await tester.pumpAndSettle();
      expect(
        container.read(mealDecisionDemoControllerProvider)['meal']!.claimedById,
        'demo-second',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(mealDecisionDemoControllerProvider)['meal']!
            .caregiverPresent,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      containerDisposed = true;
    },
  );
}
