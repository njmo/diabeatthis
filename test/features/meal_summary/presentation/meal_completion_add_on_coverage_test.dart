import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_completion_shortfall.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_summary_carbs_hint_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'meal_completion_view_test.dart' show RecordingCompleteMealUseCase;

MealSummaryDraft pendingAddOnDraft(double eaten) => MealSummaryDraft(
  mealId: 1,
  mealStatus: 'eating-extra',
  itemIds: const [1],
  itemsById: {
    1: MealSummaryItemDraft(
      name: 'Rice',
      mealIngredientId: 1,
      plannedAmount: 100,
      reportedAmount: 200,
      consumedAmount: eaten,
      consumedConfidence: 0.75,
      amountLabel: 'g',
      gramsPerAmount: 1,
      netCarbsPerAmount: 0.2,
    ),
  },
  extraItems: const [],
);

void main() {
  final now = DateTime(2026, 11, 2, 14, 30);

  test(
    'pending add-on is not a shortfall when actual food exceeds covered carbs',
    () {
      final draft = pendingAddOnDraft(150);
      expect(
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: true,
          coveredNetCarbs: 20,
        ),
        isFalse,
      );
      expect(mealCompletionShortfallCarbs(draft, coveredNetCarbs: 20), 0);
    },
  );

  test(
    'pending add-on still reviews food below the already recorded bolus',
    () {
      final draft = pendingAddOnDraft(50);
      expect(
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: true,
          coveredNetCarbs: 20,
        ),
        isTrue,
      );
      expect(mealCompletionShortfallCarbs(draft, coveredNetCarbs: 20), 10);
      expect(
        mealCompletionNeedsShortfallReview(
          draft,
          hasRecordedBolus: false,
          coveredNetCarbs: 20,
        ),
        isFalse,
      );
    },
  );

  test(
    'ordinary summaries retain their reported baseline without add-on coverage',
    () {
      final draft = pendingAddOnDraft(150);
      expect(
        mealCompletionNeedsShortfallReview(draft, hasRecordedBolus: true),
        isTrue,
      );
      expect(mealCompletionShortfallCarbs(draft), 10);
    },
  );

  Future<void> open(
    WidgetTester tester,
    double eaten,
    List<DateTime> saves,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => PendingAddOnTestController(eaten),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: const Meal(id: 1, name: 'Rice', status: 'eating-extra'),
              timing: MealCompletionTiming(
                startedAt: now.subtract(const Duration(minutes: 30)),
                endedAt: null,
                endStatus: null,
              ),
              hasRecordedBolus: true,
              requiresBolus: true,
              coveredNetCarbs: 20,
            ),
          ),
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
                      startAdjusted: true,
                      confirmedEatingEndedAt: now,
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
    final save = find.widgetWithText(
      FilledButton,
      'Zapisz i przejdź do bolusa',
    );
    await tester.scrollUntilVisible(
      save,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(save.hitTestable(), findsOneWidget);
    expect(find.byType(MealSummaryCarbsHintCard), findsNothing);
    await tester.tap(save.hitTestable());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pending add-on labels the bolus step without false replenishment advice',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, 150, saves);
        expect(find.byType(MealShortfallReviewDialog), findsNothing);
        expect(saves, [now]);
      });
    },
  );

  testWidgets(
    'pending add-on below coverage reviews only the actually missing carbs',
    (tester) async {
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(tester, 50, saves);
        final dialog = tester.widget<MealShortfallReviewDialog>(
          find.byType(MealShortfallReviewDialog),
        );
        expect(dialog.missingCarbs, 10);
        expect(dialog.usesBolusCoverage, isTrue);
        expect(saves, isEmpty);
      });
    },
  );
}

class PendingAddOnTestController extends MealSummaryControllerNotifier {
  PendingAddOnTestController(this.eaten);
  final double eaten;
  @override
  Future<MealSummaryDraft> build(int mealId) async => pendingAddOnDraft(eaten);
}
