import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/meal_completion_decision.dart';
import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_shortfall_review_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/complete_meal_use_case.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/controllers/meal_summary_controller.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_completion_choice.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:diabeatthis/features/meal_summary/presentation/providers/meal_completion_context_provider.dart';
import 'package:diabeatthis/features/meal_summary/presentation/screens/meal_completion_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/localized_material_app.dart';
import 'meal_completion_shortfall_aaps_guard_test.dart'
    show
        ShortfallGuardController,
        ShortfallGuardLauncher,
        ShortfallGuardUseCase;

void main() {
  for (final coveredCarbs in [30.0, 10.0]) {
    testWidgets(
      'explicit correction uses reported add-on baseline; covered=$coveredCarbs',
      (tester) async {
        final harness = ExplicitCorrectionHarness();
        await withClock(Clock.fixed(harness.now), () async {
          await harness.open(tester, coveredCarbs: coveredCarbs);
          final dialog = tester.widget<MealShortfallReviewDialog>(
            find.byType(MealShortfallReviewDialog),
          );
          // Planned 40 g, reported including add-on 60 g, actually eaten 20 g.
          expect(dialog.correctionCarbs, -40);
          await tester.tap(find.text('Zapisz i skoryguj w AAPS'));
          await tester.pump();
          expect(harness.saves, isEmpty);
          expect(harness.order, isEmpty);
          expect(harness.notifications.shownEvents, isEmpty);
          expect(harness.launcher.opens, 0);

          harness.commit.complete();
          await tester.pumpAndSettle();
          expect(harness.saves.single.itemsById[1]!.consumedAmount, 100);
          expect(harness.saves.single.itemsById[1]!.reportedAmount, 300);
          expect(
            harness.saves.single.correctionChoice,
            MealCarbsCorrectionChoice.correctionRequested,
          );
          expect(harness.saves.single.itemsById[2]!.consumedAmount, 2);
          expect(harness.savedTimes, [harness.endedAt]);
          expect(harness.order, ['saved', 'notified', 'launched']);
          final event =
              harness.notifications.shownEvents.single
                  as AapsBolusSuggestionNotificationEvent;
          expect(event.mealId, 1);
          expect(event.carbs, -40);
          // The result contains 22 g total, but only 11 g still to report.
          expect(event.extendedCarbs, 11);
          expect(event.extendedCarbsAreAdditional, isTrue);
          expect(harness.launcher.opens, 1);
          expect(find.byType(MealCompletionView), findsNothing);
        });
      },
    );
  }

  testWidgets('failed explicit save never posts or opens the correction', (
    tester,
  ) async {
    final harness = ExplicitCorrectionHarness();
    await withClock(Clock.fixed(harness.now), () async {
      await harness.open(tester);
      await tester.tap(find.text('Zapisz i skoryguj w AAPS'));
      await tester.pump();
      harness.commit.completeError(
        MealSummaryCannotFinishException('Save failed'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save failed'), findsOneWidget);
      expect(harness.saves, isEmpty);
      expect(harness.order, isEmpty);
      expect(harness.notifications.shownEvents, isEmpty);
      expect(harness.launcher.opens, 0);
      expect(find.byType(MealCompletionView), findsOneWidget);
    });
  });

  testWidgets('pending bolus never offers a negative reported correction', (
    tester,
  ) async {
    final harness = ExplicitCorrectionHarness();
    await withClock(Clock.fixed(harness.now), () async {
      await harness.open(tester, requiresBolus: true);
      expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
      expect(find.text('Zapisz i skoryguj w AAPS'), findsNothing);
      expect(find.text('Zapisz bez korekty'), findsOneWidget);
      expect(harness.saves, isEmpty);
      expect(harness.notifications.shownEvents, isEmpty);
      expect(harness.launcher.opens, 0);
    });
  });

  testWidgets(
    'plain actual save above coverage does not open AAPS for reported deficit',
    (tester) async {
      final harness = ExplicitCorrectionHarness();
      await withClock(Clock.fixed(harness.now), () async {
        await harness.open(tester, coveredCarbs: 10);
        await tester.tap(find.text('Zapisz bez korekty'));
        await tester.pump();
        harness.commit.complete();
        await tester.pumpAndSettle();
        expect(harness.saves, hasLength(1));
        expect(
          harness.saves.single.correctionChoice,
          MealCarbsCorrectionChoice.withoutCorrection,
        );
        expect(harness.savedTimes, [harness.endedAt]);
        expect(harness.order, ['saved']);
        expect(harness.notifications.shownEvents, isEmpty);
        expect(harness.launcher.opens, 0);
        expect(find.byType(MealCompletionView), findsNothing);
      });
    },
  );
}

class ExplicitCorrectionHarness {
  final now = DateTime(2026, 11, 2, 14, 30);
  DateTime get endedAt => now.subtract(const Duration(minutes: 5));
  final saves = <MealSummaryDraft>[];
  final savedTimes = <DateTime>[];
  final order = <String>[];
  final commit = Completer<void>();
  late final notifications = ExplicitCorrectionNotifications(order);
  late final launcher = ExplicitCorrectionLauncher(order);

  Future<void> open(
    WidgetTester tester, {
    double coveredCarbs = 30,
    bool requiresBolus = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealSummaryControllerProvider.overrideWith(
            () => ShortfallGuardController(reportedPotatoes: 300),
          ),
          mealCompletionContextProvider(1).overrideWith(
            (ref) async => MealCompletionContext(
              meal: const Meal(id: 1, name: 'Lunch', status: 'eating-extra'),
              timing: MealCompletionTiming(
                startedAt: now.subtract(const Duration(minutes: 30)),
                endedAt: null,
                endStatus: null,
              ),
              hasRecordedBolus: true,
              requiresBolus: requiresBolus,
              coveredNetCarbs: coveredCarbs,
            ),
          ),
          completeMealUseCaseProvider.overrideWith(
            (ref) => ExplicitCorrectionUseCase(
              ref,
              saves,
              savedTimes,
              commit,
              order,
            ),
          ),
          aapsLauncherProvider.overrideWithValue(launcher),
          notificationsControllerUiProvider.overrideWithValue(notifications),
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
    final save = find.widgetWithText(
      FilledButton,
      requiresBolus ? 'Zapisz i przejdź do bolusa' : 'Zapisz podsumowanie',
    );
    expect(save.hitTestable(), findsOneWidget);
    await tester.tap(save.hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MealShortfallReviewDialog), findsOneWidget);
  }
}

class ExplicitCorrectionUseCase extends ShortfallGuardUseCase {
  ExplicitCorrectionUseCase(
    super.ref,
    super.saves,
    super.savedTimes,
    this.commit,
    this.order,
  );
  final Completer<void> commit;
  final List<String> order;

  @override
  Future<MealCompletionResult> call({
    required MealSummaryDraft draft,
    required MealCompletionChoice choice,
    required DateTime endedAt,
  }) async {
    await commit.future;
    final result = await super.call(
      draft: draft,
      choice: choice,
      endedAt: endedAt,
    );
    order.add('saved');
    return result;
  }
}

class ExplicitCorrectionNotifications extends FakeNotificationsController {
  ExplicitCorrectionNotifications(this.order);
  final List<String> order;

  @override
  Future<void> show(NotificationEvent event) async {
    order.add('notified');
    await super.show(event);
  }
}

class ExplicitCorrectionLauncher extends ShortfallGuardLauncher {
  ExplicitCorrectionLauncher(this.order);
  final List<String> order;

  @override
  Future<AapsLaunchResult> openAaps() {
    order.add('launched');
    return super.openAaps();
  }
}
