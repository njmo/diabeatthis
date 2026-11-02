import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_summary_page.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_summary_carbs_hint_card.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_summary_extra_items_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  final start = DateTime(2026, 11, 1, 14, 52);
  final mealList = find
      .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
      .first;
  final saveButton = find.widgetWithText(FilledButton, 'Zapisz podsumowanie');

  Future<void> open(
    WidgetTester tester, {
    required DateTime now,
    required List<DateTime> saves,
    String status = 'eating',
    DateTime? confirmedEnd,
    List<MealSummaryDraft>? savedDrafts,
    Future<void>? waitForSave,
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
            ),
          ),
          completeMealUseCaseProvider.overrideWith(
            (ref) => RecordingCompleteMealUseCase(
              ref,
              saves,
              savedDrafts: savedDrafts,
              waitForSave: waitForSave,
            ),
          ),
        ],
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MealSummaryPage(
                      mealId: 1,
                      finishEating: true,
                      confirmedEatingEndedAt: confirmedEnd ?? now,
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
  }

  testWidgets('requires an amount choice and going back writes nothing', (
    tester,
  ) async {
    final saves = <DateTime>[];
    final now = start.add(const Duration(minutes: 20));
    await withClock(Clock.fixed(now), () async {
      await open(tester, now: now, saves: saves);
      expect(find.text('Ile zjadłeś?'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Zapisz podsumowanie'),
        findsNothing,
      );
      await tester.tap(find.text('Inaczej'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(saves, isEmpty);
      expect(find.text('Open'), findsOneWidget);
    });
  });

  testWidgets(
    'all action saves immediately with the confirmed historical time',
    (tester) async {
      final saves = <DateTime>[];
      final now = start.add(const Duration(hours: 5));
      await withClock(Clock.fixed(now), () async {
        await open(
          tester,
          now: now,
          saves: saves,
          confirmedEnd: start.add(const Duration(minutes: 15)),
        );
        await tester.tap(find.text('Wszystko'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, 'Ile trwało jedzenie? (min)'),
          findsNothing,
        );
        expect(saves, [start.add(const Duration(minutes: 15))]);
        expect(find.text('Open'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'adjusted consumption exposes ingredients and products immediately',
    (tester) async {
      final saves = <DateTime>[];
      final now = start.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(now), () async {
        await open(tester, now: now, saves: saves);
        expect(find.text('Mniej'), findsNothing);
        expect(find.text('Więcej'), findsNothing);
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        expect(find.byType(FriendlyAmountSelector), findsOneWidget);
        expect(find.byType(MealSummaryExtraItemsSection), findsOneWidget);
        expect(saves, isEmpty);
      });
    },
  );

  testWidgets(
    'choosing all restores reported amounts without changing confidence',
    (tester) async {
      final saves = <DateTime>[];
      final savedDrafts = <MealSummaryDraft>[];
      final now = start.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(now), () async {
        await open(tester, now: now, saves: saves, savedDrafts: savedDrafts);
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealSummaryPage)),
        );
        final controller = container.read(
          mealSummaryControllerProvider(1).notifier,
        );
        controller.setConsumedAmount(1, 300);
        controller.setConsumedConfidence(1, 0.6);
        await tester.pumpAndSettle();
        final selector = tester.widget<FriendlyAmountSelector>(
          find.byType(FriendlyAmountSelector),
        );
        expect(selector.value, 300);
        expect(selector.max, isNull);
        await tester.scrollUntilVisible(
          find.text('Wszystko'),
          -250,
          scrollable: mealList,
        );
        await tester.tap(find.text('Wszystko'));
        await tester.pumpAndSettle();
        final draft = savedDrafts.single;
        expect(draft.itemsById[1]!.consumedAmount, 100);
        expect(draft.itemsById[1]!.consumedConfidence, 0.6);
        expect(find.text('Open'), findsOneWidget);
        expect(saves, hasLength(1));
      });
    },
  );

  testWidgets(
    'eating before bolus shows actual carbs without a deficit recommendation',
    (tester) async {
      final saves = <DateTime>[];
      final now = start.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(now), () async {
        await open(tester, now: now, saves: saves, status: 'eating-then-bolus');
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealSummaryPage)),
        );
        container
            .read(mealSummaryControllerProvider(1).notifier)
            .setConsumedAmount(1, 50);
        await tester.pumpAndSettle();
        final actual = find.text('Faktycznie zjedzone: 10 g węglowodanów');
        await tester.scrollUntilVisible(actual, 250, scrollable: mealList);
        expect(actual, findsOneWidget);
        expect(find.text('O 10 g mniej niż w planie'), findsOneWidget);
        expect(find.byType(MealSummaryCarbsHintCard), findsNothing);
        expect(saves, isEmpty);
      });
    },
  );
  testWidgets('all action ignores a second tap while saving', (tester) async {
    final saves = <DateTime>[];
    final waitForSave = Completer<void>();
    final now = start.add(const Duration(minutes: 20));
    await withClock(Clock.fixed(now), () async {
      await open(
        tester,
        now: now,
        saves: saves,
        waitForSave: waitForSave.future,
      );
      final action = find.text('Wszystko');
      await tester.tap(action);
      await tester.pump();
      await tester.tap(action, warnIfMissed: false);
      await tester.pump();
      expect(saves, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      waitForSave.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
    });
  });

  testWidgets('zero adjusted consumption explains why saving is disabled', (
    tester,
  ) async {
    final saves = <DateTime>[];
    final now = start.add(const Duration(minutes: 20));
    await withClock(Clock.fixed(now), () async {
      await open(tester, now: now, saves: saves);
      await tester.tap(find.text('Inaczej'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealSummaryPage)),
      );
      container
          .read(mealSummaryControllerProvider(1).notifier)
          .setConsumedAmount(1, 0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(saveButton, 250, scrollable: mealList);
      expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);
      expect(find.textContaining('nie zjedzono'), findsOneWidget);
      expect(saves, isEmpty);
    });
  });
}

class CompletionTestController extends MealSummaryControllerNotifier {
  CompletionTestController(this.status);
  final String status;
  @override
  Future<MealSummaryDraft> build(int mealId) async => MealSummaryDraft(
    mealId: 1,
    mealStatus: status,
    itemIds: [1],
    itemsById: {
      1: MealSummaryItemDraft(
        name: 'Rice',
        mealIngredientId: 1,
        plannedAmount: 100,
        reportedAmount: 100,
        amountLabel: 'g',
        netCarbsPerAmount: 0.2,
        consumedAmount: 100,
        consumedConfidence: 0.8,
        gramsPerAmount: 1,
      ),
    },
    extraItems: [],
  );
}

class RecordingCompleteMealUseCase extends CompleteMealUseCase {
  RecordingCompleteMealUseCase(
    super.ref,
    this.saves, {
    this.savedDrafts,
    this.waitForSave,
  });
  final List<MealSummaryDraft>? savedDrafts;
  final Future<void>? waitForSave;
  final List<DateTime> saves;
  @override
  Future<MealCompletionResult> call({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) async {
    saves.add(endedAt);
    savedDrafts?.add(draft);
    if (waitForSave != null) await waitForSave;
    return MealCompletionResult(
      meal: const Meal(id: 1, name: 'Lunch', status: 'eating'),
      requiresBolus: false,
      consumedCarbs: 20,
      endedAt: endedAt,
    );
  }
}
