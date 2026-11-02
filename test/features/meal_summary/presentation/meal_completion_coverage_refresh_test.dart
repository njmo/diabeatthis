import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';
import 'meal_completion_shortfall_aaps_guard_test.dart'
    show ShortfallGuardController;

void main() {
  for (final retryAfterStale in [false, true]) {
    testWidgets(
      'completion reviews fresh coverage before saving; retry=$retryAfterStale',
      (tester) async {
        final now = DateTime(2026, 11, 2, 14, 30);
        final endedAt = now.subtract(const Duration(minutes: 5));
        var coveredCarbs = 20.0;
        var contextReads = 0;
        final attempts = <MealSummaryDraft>[];
        final savedTimes = <DateTime>[];
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                mealSummaryControllerProvider.overrideWith(
                  () => ShortfallGuardController(reportedPotatoes: 100),
                ),
                mealCompletionContextProvider(1).overrideWith((ref) async {
                  contextReads++;
                  return MealCompletionContext(
                    meal: const Meal(
                      id: 1,
                      name: 'Lunch',
                      status: 'eating-extra',
                    ),
                    timing: MealCompletionTiming(
                      startedAt: now.subtract(const Duration(minutes: 30)),
                      endedAt: null,
                      endStatus: null,
                    ),
                    hasRecordedBolus: true,
                    coveredNetCarbs: coveredCarbs,
                    bolusCoverage: MealBolusCoverage(
                      carbs: coveredCarbs,
                      hasRecordedBolus: true,
                      statusBaselineCarbs: 20,
                    ),
                  );
                }),
                completeMealUseCaseProvider.overrideWith(
                  (ref) => RefreshCoverageUseCase(
                    ref,
                    attempts,
                    savedTimes,
                    failFirst: retryAfterStale,
                  ),
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
                            confirmedEatingEndedAt: endedAt,
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
          expect(contextReads, 1);
          expect(find.byType(MealShortfallReviewDialog), findsNothing);

          Future<void> pressSave() async {
            final save = find.widgetWithText(
              FilledButton,
              'Zapisz podsumowanie',
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
            await tester.tap(save.hitTestable());
            await tester.pumpAndSettle();
          }

          // A calculator confirmation changes coverage while status and the
          // originally displayed ingredient draft remain unchanged.
          coveredCarbs = 40;
          await pressSave();
          expect(contextReads, 2);
          expect(
            tester
                .widget<MealShortfallReviewDialog>(
                  find.byType(MealShortfallReviewDialog),
                )
                .missingCarbs,
            20,
          );
          expect(attempts, isEmpty);
          await tester.tap(find.text('Zapisz bez korekty'));
          await tester.pumpAndSettle();
          expect(attempts.single.reviewedBolusCoverage!.carbs, 40);
          expect(
            attempts.single.reviewedBolusCoverage!.hasRecordedBolus,
            isTrue,
          );

          if (retryAfterStale) {
            expect(savedTimes, isEmpty);
            expect(find.text('Coverage changed'), findsOneWidget);
            coveredCarbs = 60;
            await pressSave();
            expect(contextReads, 3);
            expect(
              tester
                  .widget<MealShortfallReviewDialog>(
                    find.byType(MealShortfallReviewDialog),
                  )
                  .missingCarbs,
              40,
            );
            await tester.tap(find.text('Zapisz bez korekty'));
            await tester.pumpAndSettle();
            expect(attempts, hasLength(2));
            expect(attempts.last.reviewedBolusCoverage!.carbs, 60);
          }
          expect(savedTimes, [endedAt]);
          expect(find.byType(MealCompletionView), findsNothing);
        });
      },
    );
  }
}

class RefreshCoverageUseCase extends CompleteMealUseCase {
  RefreshCoverageUseCase(
    super.ref,
    this.attempts,
    this.savedTimes, {
    required this.failFirst,
  });

  final List<MealSummaryDraft> attempts;
  final List<DateTime> savedTimes;
  final bool failFirst;

  @override
  Future<MealCompletionResult> call({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) async {
    attempts.add(draft);
    if (failFirst && attempts.length == 1) {
      throw MealSummaryCannotFinishException('Coverage changed');
    }
    savedTimes.add(endedAt);
    return MealCompletionResult(
      meal: const Meal(id: 1, name: 'Lunch', status: 'summarized'),
      requiresBolus: false,
      consumedCarbs: 20,
      aapsCarbs: const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 0),
      endedAt: endedAt,
    );
  }
}
