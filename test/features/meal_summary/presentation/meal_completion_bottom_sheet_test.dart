import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/meal/open_meal_completion.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_choice_sheet.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_time_section.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'meal_completion_view_test.dart'
    show CompletionTestController, RecordingCompleteMealUseCase;

void main() {
  final start = DateTime(2026, 11, 1, 14);
  final now = start.add(const Duration(hours: 5));

  Future<void> open(
    WidgetTester tester, {
    required List<DateTime> saves,
    bool earlier = false,
    String status = 'eating',
    String mealName = 'Lunch',
    Future<void>? saveWait,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => CompletionTestController(status),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: Meal(id: 1, name: mealName, status: status),
              timing: MealCompletionTiming(
                startedAt: start,
                endedAt: null,
                endStatus: null,
              ),
              hasRecordedBolus: status == 'bolused-eating',
            ),
          ),
          completeMealUseCaseProvider.overrideWith(
            (ref) =>
                RecordingCompleteMealUseCase(ref, saves, waitForSave: saveWait),
          ),
        ],
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openMealCompletion(
                  context,
                  mealId: 1,
                  chooseEarlier: earlier,
                  confirmedEatingEndedAt: earlier ? null : now,
                ),
                child: const Text('Home meal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Home meal'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'everyday choice is a compact bottom sheet and dismissal writes nothing',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, saves: saves);
        final sheet = find.byType(MealCompletionChoiceSheet);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(tester.getSize(sheet).height, lessThan(320));
        expect(tester.getTopLeft(sheet).dy, greaterThan(250));
        expect(find.byType(FriendlyAmountSelector), findsNothing);
        expect(find.byType(MealCompletionTimeSection), findsNothing);
        await tester.tap(find.byTooltip('Zamknij'));
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(saves, isEmpty);
        expect(find.text('Home meal'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'as planned saves once in the sheet and disables actions while saving',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final wait = Completer<void>();
        await open(tester, saves: saves, saveWait: wait.future);
        await tester.tap(find.text('Wszystko'));
        await tester.pump();
        expect(saves, [now]);
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Wszystko'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Inaczej'),
              )
              .onPressed,
          isNull,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        wait.complete();
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionChoiceSheet), findsNothing);
        expect(find.byType(MealCompletionView), findsNothing);
        expect(saves, hasLength(1));
      });
    },
  );

  testWidgets(
    'compact choice keeps the quick meal name and scrolls at large text size',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(
          tester,
          saves: saves,
          mealName: 'QM: Tost z pomidorem i serem',
        );
        expect(find.text('Tost z pomidorem i serem'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(
          find.descendant(
            of: find.byType(MealCompletionChoiceSheet),
            matching: find.byType(SingleChildScrollView),
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Inaczej'));
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionChoiceSheet), findsNothing);
        expect(saves, isEmpty);
      });
    },
  );

  testWidgets(
    'pending save cannot be dismissed by barrier, system back, or drag',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final wait = Completer<void>();
        await open(tester, saves: saves, saveWait: wait.future);
        await tester.tap(find.text('Wszystko'));
        await tester.pump();
        final sheet = find.byType(MealCompletionChoiceSheet);
        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).enableDrag,
          isFalse,
        );
        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
          isFalse,
        );
        await tester.tapAt(const Offset(8, 8));
        await tester.pump();
        expect(sheet, findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(sheet, findsOneWidget);
        await tester.drag(sheet, const Offset(0, 500));
        await tester.pump();
        expect(sheet, findsOneWidget);
        expect(saves, [now]);
        wait.complete();
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(find.byType(MealCompletionView), findsNothing);
        expect(saves, hasLength(1));
      });
    },
  );

  testWidgets(
    'different opens the full ingredient editor without repeating choice or time',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, saves: saves);
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final view = tester.widget<MealCompletionView>(
          find.byType(MealCompletionView),
        );
        expect(view.startAdjusted, isTrue);
        expect(view.confirmedEatingEndedAt, now);
        expect(find.byType(MealCompletionChoiceSheet), findsNothing);
        expect(find.byType(FriendlyAmountSelector), findsOneWidget);
        expect(find.text('Wszystko'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Inaczej'), findsNothing);
        expect(find.byType(MealCompletionTimeSection), findsNothing);
        expect(saves, isEmpty);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Home meal'), findsOneWidget);
        expect(saves, isEmpty);
      });
    },
  );

  testWidgets(
    'a repeated different action opens one editor and preserves the home route',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, saves: saves);
        final action = tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Inaczej'),
            )
            .onPressed!;
        action();
        action();
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionView), findsOneWidget);
        expect(
          tester
              .widget<MealCompletionView>(find.byType(MealCompletionView))
              .startAdjusted,
          isTrue,
        );
        expect(saves, isEmpty);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Home meal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );

  testWidgets('earlier time is collected before the compact amount choice', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final saves = <DateTime>[];
      await open(tester, saves: saves, earlier: true);
      expect(find.byType(MealCompletionChoiceSheet), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Ile trwało jedzenie? (min)'),
        '15',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dalej do podsumowania'));
      await tester.pumpAndSettle();
      expect(find.byType(MealCompletionTimeSection), findsNothing);
      expect(find.byType(MealCompletionChoiceSheet), findsOneWidget);
      await tester.tap(find.text('Wszystko'));
      await tester.pumpAndSettle();
      expect(saves, [start.add(const Duration(minutes: 15))]);
    });
  });

  testWidgets(
    'eat-first sheet explains the next bolus step and can open adjusted quantities',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, saves: saves, status: 'eating-then-bolus');
        expect(
          find.text('Zapisz zjedzoną porcję i przejdź do bolusa.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final save = find.widgetWithText(
          FilledButton,
          'Zapisz i przejdź do bolusa',
        );
        await tester.scrollUntilVisible(
          save,
          300,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(save, findsOneWidget);
        expect(find.textContaining('dojedzenie'), findsNothing);
        expect(saves, isEmpty);
      });
    },
  );

  testWidgets(
    'post-bolus partial quantity still requires the shortfall review after the sheet',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, saves: saves, status: 'bolused-eating');
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealCompletionView)),
        );
        container
            .read(mealSummaryControllerProvider(1).notifier)
            .setConsumedAmount(1, 50);
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Zapisz podsumowanie');
        await tester.scrollUntilVisible(
          save,
          300,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
        expect(saves, isEmpty);
        await tester.tap(find.text('Zapisz bez korekty'));
        await tester.pumpAndSettle();
        expect(saves, [now]);
      });
    },
  );
}
