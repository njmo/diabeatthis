import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_eating_finish_time_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 11, 1, 20, 45);
  final durationField = find.widgetWithText(
    TextField,
    'Ile trwało jedzenie? (min)',
  );
  final continueButton = find.widgetWithText(
    FilledButton,
    'Dalej do podsumowania',
  );

  Future<void> openWithFutureEnd(
    WidgetTester tester,
    List<DateTime> confirmed,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var completed = false;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => completed
              ? const Scaffold(body: Text('Quantities only'))
              : MealEatingFinishTimeStep(
                  mealName: 'Dinner',
                  timing: MealCompletionTiming(
                    startedAt: start,
                    endedAt: null,
                    endStatus: null,
                  ),
                  onConfirmed: (value) {
                    confirmed.add(value);
                    setState(() => completed = true);
                  },
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zjadłem wcześniej'));
    await tester.pumpAndSettle();
    await tester.enterText(durationField, '5');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    expect(
      find.textContaining('Ta godzina jeszcze nie nadeszła.'),
      findsOneWidget,
    );
    expect(confirmed, isEmpty);
  }

  testWidgets(
    'future duration becomes valid automatically before entering quantity summary',
    (tester) async {
      var now = start.add(const Duration(minutes: 3));
      final confirmed = <DateTime>[];
      await withClock(Clock(() => now), () async {
        await openWithFutureEnd(tester, confirmed);
        now = start.add(const Duration(minutes: 4, seconds: 59));
        await tester.pump(const Duration(minutes: 1, seconds: 59));
        expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
        now = start.add(const Duration(minutes: 5));
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.widget<FilledButton>(continueButton).onPressed,
          isNotNull,
        );
        expect(
          find.textContaining('Ta godzina jeszcze nie nadeszła.'),
          findsNothing,
        );
        expect(confirmed, isEmpty);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        expect(confirmed, [now]);
        expect(find.text('Quantities only'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'finished now discards invalid duration before entering quantity summary',
    (tester) async {
      final now = start.add(const Duration(minutes: 3));
      final confirmed = <DateTime>[];
      await withClock(Clock.fixed(now), () async {
        await openWithFutureEnd(tester, confirmed);
        await tester.tap(find.text('Zjadłem teraz'));
        await tester.pumpAndSettle();
        expect(confirmed, [now]);
        expect(durationField, findsNothing);
        expect(find.text('Quantities only'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );

  testWidgets(
    'resuming refreshes time validity without confirming or changing the chosen end',
    (tester) async {
      var now = start.add(const Duration(minutes: 3));
      final confirmed = <DateTime>[];
      await withClock(Clock(() => now), () async {
        await openWithFutureEnd(tester, confirmed);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = start.add(const Duration(minutes: 6));
        await tester.pump(const Duration(minutes: 3));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          tester.widget<FilledButton>(continueButton).onPressed,
          isNotNull,
        );
        expect(confirmed, isEmpty);
        await tester.tap(continueButton);
        await tester.pumpAndSettle();
        expect(confirmed, [start.add(const Duration(minutes: 5))]);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    },
  );
}
