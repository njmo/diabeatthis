import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/meal/open_meal_completion.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_choice_sheet.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_completion_time_section.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_eating_finish_time_step.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_item_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:diabeatthis/features/meal_summary/presentation/widgets/meal_completion_quantity_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/localized_material_app.dart';
import 'meal_completion_view_test.dart' show RecordingCompleteMealUseCase;

void main() {
  final start = DateTime(2026, 11, 2, 14);

  Future<void> open(
    WidgetTester tester, {
    required DateTime now,
    required List<DateTime> saves,
    required List<MealSummaryDraft> drafts,
    required FakeNotificationsController notifications,
    double reportedMeatballs = 1,
    bool missingStart = false,
    bool hasBolus = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => SharedCompletionTestController(reportedMeatballs),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: const Meal(id: 1, name: 'Obiad', status: 'eating'),
              timing: MealCompletionTiming(
                startedAt: missingStart ? null : start,
                endedAt: null,
                endStatus: null,
              ),
              hasRecordedBolus: hasBolus,
            ),
          ),
          completeMealUseCaseProvider.overrideWith(
            (ref) =>
                RecordingCompleteMealUseCase(ref, saves, savedDrafts: drafts),
          ),
          notificationsControllerUiProvider.overrideWithValue(notifications),
          aapsLauncherProvider.overrideWithValue(
            SharedCompletionAapsLauncher(),
          ),
          extendedCarbsScheduleSettingsProvider.overrideWith(
            (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
          ),
        ],
        child: localizedMaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => openMealCompletion(context, mealId: 1),
                child: const Text('Zjadłem'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Zjadłem'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseEarlier(WidgetTester tester, int minutes) async {
    await tester.tap(find.text('Zjadłem wcześniej'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Ile trwało jedzenie? (min)'),
      '$minutes',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalej do podsumowania'));
    await tester.pumpAndSettle();
  }

  test(
    'automatic current end stops exactly at one hour and requires a real start',
    () {
      final timing = MealCompletionTiming(
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 15)),
        endStatus: 'eaten',
      );
      expect(
        timing.canAssumeEndedNow(
          start.add(const Duration(minutes: 59, seconds: 59)),
        ),
        isTrue,
      );
      expect(
        timing.canAssumeEndedNow(start.add(const Duration(hours: 1))),
        isFalse,
      );
      expect(timing.isLateReport(start.add(const Duration(hours: 5))), isTrue);
      expect(
        timing.canAssumeEndedNow(start.subtract(const Duration(seconds: 1))),
        isFalse,
      );
      expect(
        const MealCompletionTiming(
          startedAt: null,
          endedAt: null,
          endStatus: null,
        ).canAssumeEndedNow(start),
        isFalse,
      );
    },
  );

  testWidgets(
    'one early finish opens the small quantity choice with an earlier-time option',
    (tester) async {
      final now = start.add(const Duration(minutes: 30));
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final drafts = <MealSummaryDraft>[];
        await open(
          tester,
          now: now,
          saves: saves,
          drafts: drafts,
          notifications: FakeNotificationsController(),
        );
        expect(find.byType(MealCompletionChoiceSheet), findsOneWidget);
        expect(find.byType(MealEatingFinishTimeStep), findsNothing);
        expect(find.text('Zjadłem wcześniej'), findsOneWidget);
        expect(saves, isEmpty);
        await chooseEarlier(tester, 15);
        expect(find.byType(MealCompletionChoiceSheet), findsOneWidget);
        expect(find.byType(MealCompletionTimeSection), findsNothing);
        await tester.tap(find.text('Wszystko'));
        await tester.pumpAndSettle();
        expect(saves, [start.add(const Duration(minutes: 15))]);
        expect(drafts.single.itemsById[1]!.consumedConfidence, 0.75);
      });
    },
  );

  for (final elapsed in [const Duration(hours: 1), const Duration(hours: 5)]) {
    testWidgets('finish after $elapsed asks time before quantity', (
      tester,
    ) async {
      final now = start.add(elapsed);
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        await open(
          tester,
          now: now,
          saves: saves,
          drafts: [],
          notifications: FakeNotificationsController(),
        );
        expect(find.byType(MealEatingFinishTimeStep), findsOneWidget);
        expect(find.byType(MealCompletionChoiceSheet), findsNothing);
        await tester.tap(find.text('Zjadłem teraz'));
        await tester.pumpAndSettle();
        expect(find.byType(MealCompletionChoiceSheet), findsOneWidget);
        expect(saves, isEmpty);
      });
    });
  }

  testWidgets(
    'early reported add-on is included in all without duplicate carbs or lost confidence',
    (tester) async {
      final now = start.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final drafts = <MealSummaryDraft>[];
        final notifications = FakeNotificationsController();
        await open(
          tester,
          now: now,
          saves: saves,
          drafts: drafts,
          notifications: notifications,
          reportedMeatballs: 2,
          hasBolus: true,
        );
        await tester.tap(find.text('Wszystko'));
        await tester.pumpAndSettle();
        expect(saves, [now]);
        expect(drafts.single.itemsById[1]!.consumedAmount, 2);
        expect(drafts.single.itemsById[1]!.consumedConfidence, 0.75);
        expect(drafts.single.itemsById[2]!.consumedAmount, 200);
        expect(notifications.shownEvents, isEmpty);
      });
    },
  );

  testWidgets(
    'late extra meatball finalizes from the same editor with only additional eCarbs',
    (tester) async {
      final now = start.add(const Duration(hours: 5));
      await withClock(Clock.fixed(now), () async {
        final saves = <DateTime>[];
        final drafts = <MealSummaryDraft>[];
        final notifications = FakeNotificationsController();
        await open(
          tester,
          now: now,
          saves: saves,
          drafts: drafts,
          notifications: notifications,
          hasBolus: true,
        );
        await chooseEarlier(tester, 20);
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        final section = tester.widget<MealCompletionQuantitySection>(
          find.byType(MealCompletionQuantitySection),
        );
        expect(section.showConfidence, isTrue);
        expect(section.showChoice, isFalse);
        expect(find.byType(MealCompletionTimeSection), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealCompletionView)),
        );
        container
            .read(mealSummaryControllerProvider(1).notifier)
            .setConsumedAmount(1, 2);
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
        await tester.pumpAndSettle();
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();
        expect(save.hitTestable(), findsOneWidget);
        expect(find.text('Zapisz dokładkę i wróć do jedzenia'), findsNothing);
        await tester.tap(save.hitTestable());
        await tester.pumpAndSettle();
        expect(saves, [start.add(const Duration(minutes: 20))]);
        expect(drafts.single.itemsById[1]!.consumedAmount, 2);
        expect(drafts.single.itemsById[2]!.consumedAmount, 200);
        expect(find.byType(MealCompletionView), findsNothing);
        final event =
            notifications.shownEvents.single
                as AapsBolusSuggestionNotificationEvent;
        expect(event.carbs, 5);
        expect(event.extendedCarbs, 15);
      });
    },
  );

  testWidgets(
    'the early editor hides estimation without changing previously recorded certainty',
    (tester) async {
      final now = start.add(const Duration(minutes: 20));
      await withClock(Clock.fixed(now), () async {
        await open(
          tester,
          now: now,
          saves: [],
          drafts: [],
          notifications: FakeNotificationsController(),
          reportedMeatballs: 2,
        );
        await tester.tap(find.text('Inaczej'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MealCompletionQuantitySection>(
                find.byType(MealCompletionQuantitySection),
              )
              .showConfidence,
          isFalse,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MealCompletionView)),
        );
        expect(
          container
              .read(mealSummaryControllerProvider(1))
              .requireValue
              .itemsById[1]!
              .consumedConfidence,
          0.75,
        );
      });
    },
  );
}

class SharedCompletionTestController extends MealSummaryControllerNotifier {
  SharedCompletionTestController(this.reportedMeatballs);
  final double reportedMeatballs;

  @override
  Future<MealSummaryDraft> build(int mealId) async => MealSummaryDraft(
    mealId: mealId,
    mealStatus: 'eating',
    itemIds: const [1, 2],
    itemsById: {
      1: MealSummaryItemDraft(
        name: 'Kotlet',
        mealIngredientId: 1,
        plannedAmount: 1,
        reportedAmount: reportedMeatballs,
        amountLabel: 'szt.',
        gramsPerAmount: 50,
        netCarbsPerAmount: 5,
        fatPerAmount: 8,
        proteinPerAmount: 20,
        consumedAmount: reportedMeatballs,
        consumedConfidence: 0.75,
      ),
      2: const MealSummaryItemDraft(
        name: 'Ziemniaki',
        mealIngredientId: 2,
        plannedAmount: 200,
        reportedAmount: 200,
        amountLabel: 'g',
        gramsPerAmount: 1,
        netCarbsPerAmount: 0.2,
        consumedAmount: 200,
        consumedConfidence: 1,
      ),
    },
    extraItems: const [],
  );
}

class SharedCompletionAapsLauncher extends AapsLauncher {
  @override
  Future<AapsLaunchResult> openAaps() async => AapsLaunchResult.opened;
}
