import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/localized_material_app.dart';

void main() {
  for (final coveredCarbs in <double?>[null, 40]) {
    testWidgets(
      'actual shortfall save suppresses additional eCarbs with coverage $coveredCarbs',
      (tester) async {
        final now = DateTime(2026, 11, 2, 14, 30);
        final endedAt = now.subtract(const Duration(minutes: 5));
        final saves = <MealSummaryDraft>[];
        final savedTimes = <DateTime>[];
        final launcher = ShortfallGuardLauncher();
        final notifications = FakeNotificationsController();
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                mealSummaryControllerProvider.overrideWith(
                  () => ShortfallGuardController(
                    // The second case also proves a positive reported-baseline delta
                    // cannot fall through to the legacy suggestion after suppression.
                    reportedPotatoes: coveredCarbs == null ? 200 : 50,
                  ),
                ),
                mealCompletionContextProvider(1).overrideWith(
                  (ref) async => MealCompletionContext(
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
                  ),
                ),
                completeMealUseCaseProvider.overrideWith(
                  (ref) => ShortfallGuardUseCase(ref, saves, savedTimes),
                ),
                aapsLauncherProvider.overrideWithValue(launcher),
                notificationsControllerUiProvider.overrideWithValue(
                  notifications,
                ),
                extendedCarbsScheduleSettingsProvider.overrideWith(
                  (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
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
          final save = find.widgetWithText(FilledButton, 'Zapisz podsumowanie');
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
          expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
          expect(saves, isEmpty);

          await tester.tap(find.text('Zapisz bez korekty'));
          await tester.pumpAndSettle();
          expect(saves, hasLength(1));
          expect(saves.single.itemsById[1]!.consumedAmount, 100);
          expect(saves.single.itemsById[2]!.consumedAmount, 2);
          expect(savedTimes, [endedAt]);
          expect(launcher.opens, 0);
          expect(notifications.shownEvents, isEmpty);
          expect(find.byType(MealCompletionView), findsNothing);
        });
      },
    );
  }
}

class ShortfallGuardController extends MealSummaryControllerNotifier {
  ShortfallGuardController({required this.reportedPotatoes});

  final double reportedPotatoes;

  @override
  Future<MealSummaryDraft> build(int mealId) async => MealSummaryDraft(
    mealId: mealId,
    mealStatus: 'eating-extra',
    itemIds: const [1, 2],
    itemsById: {
      1: MealSummaryItemDraft(
        name: 'Potatoes',
        mealIngredientId: 1,
        plannedAmount: 200,
        reportedAmount: reportedPotatoes,
        consumedAmount: 100,
        consumedConfidence: 1,
        amountLabel: 'g',
        netCarbsPerAmount: 0.2,
        gramsPerAmount: 1,
      ),
      2: const MealSummaryItemDraft(
        name: 'Meatball',
        mealIngredientId: 2,
        plannedAmount: 1,
        reportedAmount: 1,
        consumedAmount: 2,
        consumedConfidence: 1,
        amountLabel: 'szt.',
        netCarbsPerAmount: 0,
        gramsPerAmount: 50,
        proteinPerAmount: 20,
        fatPerAmount: 8,
      ),
    },
    extraItems: const [],
  );
}

class ShortfallGuardUseCase extends CompleteMealUseCase {
  ShortfallGuardUseCase(super.ref, this.saves, this.savedTimes);

  final List<MealSummaryDraft> saves;
  final List<DateTime> savedTimes;

  @override
  Future<MealCompletionResult> call({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) async {
    saves.add(draft);
    savedTimes.add(endedAt);
    return MealCompletionResult(
      meal: const Meal(id: 1, name: 'Lunch', status: 'summarized'),
      requiresBolus: false,
      consumedCarbs: 20,
      consumedExtendedCarbs: 22,
      aapsCarbs: const MealSummaryAapsCarbs(carbs: 0, extendedCarbs: 11),
      endedAt: endedAt,
    );
  }
}

class ShortfallGuardLauncher extends AapsLauncher {
  int opens = 0;

  @override
  Future<AapsLaunchResult> openAaps() async {
    opens++;
    return AapsLaunchResult.opened;
  }
}
