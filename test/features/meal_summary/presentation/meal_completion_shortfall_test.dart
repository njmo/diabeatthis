import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_bolus_evidence.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/widgets/current_glucose_summary.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_completion_shortfall.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'meal_completion_view_test.dart'
    show CompletionTestController, RecordingCompleteMealUseCase;

void main() {
  final start = DateTime(2026, 11, 1, 14);
  final historicalEnd = start.add(const Duration(minutes: 15));
  final now = start.add(const Duration(hours: 5));

  test('bolus evidence uses confirmed statuses and history only', () {
    for (final status in [
      'bolused-waiting',
      'bolused-eating',
      'waited-eating',
      'eaten-bolused',
    ]) {
      expect(mealHasRecordedBolus(currentStatus: status), isTrue);
      expect(
        mealHasRecordedBolus(currentStatus: 'eaten', history: [status]),
        isTrue,
      );
    }
    for (final status in [
      'planned',
      'waiting-for-bolus',
      'eating',
      'eating-then-bolus',
      'eaten',
    ]) {
      expect(mealHasRecordedBolus(currentStatus: status), isFalse);
    }
  });

  test(
    'refill uses final confirmation time while corrections keep history',
    () {
      expect(
        mealCompletionEndForSave(
          confirmedEndedAt: historicalEnd,
          finishedRefill: false,
          now: now,
        ),
        historicalEnd,
      );
      expect(
        mealCompletionEndForSave(
          confirmedEndedAt: historicalEnd,
          finishedRefill: true,
          now: now,
        ),
        now,
      );
    },
  );

  Future<ProviderContainer> open(
    WidgetTester tester, {
    required List<DateTime> saves,
    String status = 'bolused-eating',
    bool hasBolus = true,
    Meal? blockingMeal,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => CompletionTestController(status),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: Meal(id: 1, name: 'Lunch', status: status),
              timing: MealCompletionTiming(
                startedAt: start,
                endedAt: null,
                endStatus: null,
              ),
              hasRecordedBolus: hasBolus,
            ),
          ),
          mealBlockingActivationProvider(
            1,
          ).overrideWith((ref) async => blockingMeal),
          completeMealUseCaseProvider.overrideWith(
            (ref) => RecordingCompleteMealUseCase(ref, saves),
          ),
        ],
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MealCompletionView(
                      mealId: 1,
                      confirmedEatingEndedAt: historicalEnd,
                    ),
                  ),
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
    await tester.tap(find.text('Inaczej'));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MealCompletionView)),
    );
    container
        .read(mealSummaryControllerProvider(1).notifier)
        .setConsumedAmount(1, 50);
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> attemptSave(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Zapisz podsumowanie');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    await tester.tap(button.hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'post-bolus shortfall needs explicit actual-save and preserves earlier time',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final container = await open(tester, saves: saves);
        final draft = container
            .read(mealSummaryControllerProvider(1))
            .requireValue;
        expect(
          mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: true),
          isFalse,
        );
        await attemptSave(tester);
        expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
        expect(find.text('Popraw'), findsOneWidget);
        expect(saves, isEmpty);
        await tester.tap(find.text('Zapisz bez korekty'));
        await tester.pumpAndSettle();
        expect(saves, [historicalEnd]);
        expect(find.text('Open'), findsOneWidget);
      });
    },
  );

  testWidgets('inline glucose and editing amounts keep the draft unsaved', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final saves = <DateTime>[];
      final container = await open(tester, saves: saves);
      await attemptSave(tester);
      expect(find.byType(CurrentGlucoseSummary), findsOneWidget);
      expect(find.text('Sprawdź glikemię'), findsNothing);
      expect(saves, isEmpty);
      expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
      await tester.tap(find.text('Popraw'));
      await tester.pumpAndSettle();
      expect(find.byType(MealShortfallReviewDialog), findsNothing);
      expect(
        container
            .read(mealSummaryControllerProvider(1))
            .requireValue
            .itemsById[1]!
            .consumedAmount,
        50,
      );
      expect(saves, isEmpty);
    });
  });

  testWidgets(
    'manual eating without a recorded bolus has facts and no refill advice',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final container = await open(
          tester,
          saves: saves,
          status: 'eating',
          hasBolus: false,
        );
        final draft = container
            .read(mealSummaryControllerProvider(1))
            .requireValue;
        expect(
          mealCompletionNeedsShortfallReview(draft, hasRecordedBolus: false),
          isFalse,
        );
        expect(
          mealCompletionCanOpenAapsSuggestion(draft, hasRecordedBolus: false),
          isFalse,
        );
        await attemptSave(tester);
        expect(find.byType(MealShortfallReviewDialog), findsNothing);
        expect(saves, [historicalEnd]);
      });
    },
  );

  testWidgets('ready meal cannot start a refill while another meal is active', (
    tester,
  ) async {
    await withClock(Clock.fixed(now), () async {
      final saves = <DateTime>[];
      await open(
        tester,
        saves: saves,
        status: 'eaten',
        blockingMeal: const Meal(id: 2, name: 'Dinner', status: 'eating'),
      );
      await attemptSave(tester);
      await tester.tap(find.text('Popraw'));
      await tester.pumpAndSettle();
      expect(find.byType(MealShortfallReviewDialog), findsNothing);
      expect(saves, isEmpty);
      final addFood = find.widgetWithText(FilledButton, 'Dodaj');
      await tester.scrollUntilVisible(
        addFood,
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(addFood.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(AddMealIngredient), findsNothing);
      expect(find.textContaining('Dinner'), findsOneWidget);
      expect(saves, isEmpty);
    });
  });

  testWidgets(
    'eat-first never reviews shortfall even with an old bolus record',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final container = await open(
          tester,
          saves: saves,
          status: 'eating-then-bolus',
        );
        final draft = container
            .read(mealSummaryControllerProvider(1))
            .requireValue;
        expect(
          mealCompletionNeedsShortfallReview(draft, hasRecordedBolus: true),
          isFalse,
        );
        expect(find.textContaining('dojedzenie'), findsNothing);
        expect(saves, isEmpty);
      });
    },
  );
}
