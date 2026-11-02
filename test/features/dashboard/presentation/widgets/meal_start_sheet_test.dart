import 'dart:async';

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/manual_meal_decision_dialog.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/wbt_extended_carbs_calculator.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('planned meal opens a sheet and skip supports back and cancel', (
    tester,
  ) async {
    final controller = MealSheetTestController();
    final results = <MealStatusDialogResult?>[];
    await openMealSheet(tester, controller: controller, onResult: results.add);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Ten posiłek?'), findsOneWidget);
    expect(find.text('Zjem'), findsOneWidget);
    expect(find.text('Pomijam'), findsOneWidget);

    await tester.tap(find.text('Pomijam'));
    await tester.pumpAndSettle();
    expect(find.text('Potwierdź pominięcie posiłku'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Zjem'), findsOneWidget);

    await tester.tap(find.text('Pomijam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(results, [null]);
    expect(controller.saves, 0);
    expect(controller.cancelledNotifications, 0);
    expect(controller.pendingReminderCancellations, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back from advice cancels its pending reminder before choosing skip',
    (tester) async {
      final controller = MealSheetTestController(
        initialState: mealSheetAdviceState(),
      );
      final results = <MealStatusDialogResult?>[];
      await openMealSheet(
        tester,
        controller: controller,
        onResult: results.add,
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Zjem'), findsOneWidget);
      expect(controller.pendingReminderCancellations, 1);
      expect(controller.cancelledNotifications, 0);

      await tester.tap(find.text('Pomijam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(results, [null]);
      expect(controller.pendingReminderCancellations, 1);
      expect(controller.cancelledNotifications, 0);
      expect(controller.saves, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('confirming skip returns only a skipped status', (tester) async {
    final controller = MealSheetTestController();
    MealStatusDialogResult? result;
    await openMealSheet(
      tester,
      controller: controller,
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('Pomijam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Potwierdzam'));
    await tester.pumpAndSettle();

    expect(result, isA<MealStatusUpdateResult>());
    final update = result as MealStatusUpdateResult;
    expect(update.status, 'skipped');
    expect(update.alreadySaved, isFalse);
    expect(controller.saves, 0);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'changing the plan keeps reviewed grams and custom eCarbs schedule visible',
    (tester) async {
      final controller = MealSheetTestController(
        initialState: mealSheetAdviceState(),
      );
      await openMealSheet(tester, controller: controller);
      expect(find.text('45 g'), findsOneWidget);
      expect(find.text('12 g'), findsOneWidget);
      expect(
        find.text('12 g • start po 30 min • przez 90 min'),
        findsOneWidget,
      );
      expect(find.text('15 min po zapisie bolusa'), findsOneWidget);

      await tester.tap(find.text('Zmień decyzję'));
      await tester.pumpAndSettle();
      expect(find.byType(ManualMealDecisionDialog), findsOneWidget);
      expect(
        find.text('Gramy i harmonogram eCarbs pozostają bez zmian.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Insulina i jedzenie bez czekania'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zastosuj zmianę'));
      await tester.pumpAndSettle();

      expect(find.byType(ManualMealDecisionDialog), findsNothing);
      expect(find.text('Decyzja ręczna'), findsOneWidget);
      expect(find.text('Bolus i jedzenie od razu'), findsOneWidget);
      expect(find.text('Bez oczekiwania'), findsOneWidget);
      expect(find.text('15 min po zapisie bolusa'), findsNothing);
      expect(find.text('45 g'), findsOneWidget);
      expect(find.text('12 g'), findsOneWidget);
      expect(
        find.text('12 g • start po 30 min • przez 90 min'),
        findsOneWidget,
      );
      expect(find.textContaining('Akceptacja otworzy AAPS.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final extendedCarbs in [0, 12]) {
    testWidgets(
      'eat-first shows $extendedCarbs planned eCarbs and defers the suggestion and AAPS launch',
      (tester) async {
        await openMealSheet(
          tester,
          controller: MealSheetTestController(
            initialState: mealSheetAdviceState(
              decision: MealDecision.eatNowBolusLater,
              extendedCarbs: extendedCarbs,
            ),
          ),
        );
        expect(find.text('Najpierw jedzenie, potem bolus'), findsOneWidget);
        expect(find.text('eCarbs'), findsOneWidget);
        expect(find.text('$extendedCarbs g'), findsOneWidget);
        expect(
          find.textContaining(
            'Propozycja eCarbs pojawi się po zakończeniu jedzenia',
          ),
          findsOneWidget,
        );
        expect(find.text('Zaczynam jeść'), findsOneWidget);
        expect(find.textContaining('Akceptacja otworzy AAPS.'), findsNothing);
        expect(find.text('Harmonogram eCarbs'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'additional-bolus schedule keeps its delivery mode in the summary',
    (tester) async {
      await openMealSheet(
        tester,
        controller: MealSheetTestController(
          initialState: mealSheetAdviceState(
            deliveryMode: ExtendedCarbsDeliveryMode.extraBolus,
          ),
        ),
      );
      expect(find.text('12 g • dodatkowy bolus po 30 min'), findsOneWidget);
      expect(find.textContaining('przez 90 min'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final layout in [
    (name: 'small portrait', size: const Size(320, 640), textScale: 1.8),
    (name: 'landscape', size: const Size(700, 360), textScale: 1.3),
  ]) {
    testWidgets(
      '${layout.name} with enlarged text keeps summary scrollable and actions reachable',
      (tester) async {
        tester.view.physicalSize = layout.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final results = <MealStatusDialogResult?>[];
        await openMealSheet(
          tester,
          controller: MealSheetTestController(
            initialState: mealSheetAdviceState(),
          ),
          textScale: layout.textScale,
          onResult: results.add,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.text('12 g • start po 30 min • przez 90 min'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('12 g • start po 30 min • przez 90 min').hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Podaję bolusa i czekam'));
        await tester.pumpAndSettle();
        expect(
          find.text('Podaję bolusa i czekam').hitTestable(),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Anuluj'));
        await tester.pumpAndSettle();
        expect(find.text('Anuluj').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Anuluj'));
        await tester.pumpAndSettle();
        expect(results, [null]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'pending sheet save blocks barrier, system back and downward drag',
    (tester) async {
      final completion = Completer<bool>();
      final controller = MealSheetTestController(
        initialState: mealSheetAdviceState(),
        saveCompletion: completion,
      );
      final results = <MealStatusDialogResult?>[];
      await openMealSheet(
        tester,
        controller: controller,
        onResult: results.add,
      );
      await tester.tap(find.text('Podaję bolusa i czekam'));
      await tester.pump();
      expect(controller.saves, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Anuluj'))
            .onPressed,
        isNull,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(BottomSheet), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(find.byType(MealStatusDialog), findsOneWidget);
      expect(results, isEmpty);

      completion.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(results, hasLength(1));
      final result = results.single as MealStatusUpdateResult;
      expect(result.status, 'waiting-for-bolus');
      expect(result.alreadySaved, isTrue);
      expect(controller.saves, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

MealDialogState mealSheetAdviceState({
  MealDecision decision = MealDecision.bolusWaitThenEat,
  int extendedCarbs = 12,
  ExtendedCarbsDeliveryMode deliveryMode =
      ExtendedCarbsDeliveryMode.extendedCarbs,
}) => MealDialogState.initial(MealDialogStep.confirm).copyWith(
  carbsGrams: 45,
  extendedCarbsGrams: extendedCarbs.toDouble(),
  advice: MealAdvice(
    decision,
    decision == MealDecision.bolusWaitThenEat
        ? WaitSuggestion(15, 15, 15)
        : null,
    extendedCarbs: WbtExtendedCarbsSuggestion(
      kcal: 120,
      wbt: 1.2,
      grams: extendedCarbs,
      scheduleSettings: ExtendedCarbsScheduleSettings(
        deliveryMode: deliveryMode,
        delayMinutes: 30,
        durationMinutes: 90,
      ),
    ),
  ),
);

Future<void> openMealSheet(
  WidgetTester tester, {
  required MealSheetTestController controller,
  ValueChanged<MealStatusDialogResult?>? onResult,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealDialogControllerProvider(
          1,
          MealDialogStep.choose,
        ).overrideWith(() => controller),
        mealBlockingActivationProvider(1).overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final result = await showMealStatusDialog(
                  context: context,
                  meal: const Meal(id: 1, name: 'Obiad', status: 'planned'),
                );
                onResult?.call(result);
              },
              child: const Text('Open meal'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open meal'));
  await tester.pumpAndSettle();
}

class MealSheetTestController extends MealDialogController {
  MealSheetTestController({this.initialState, this.saveCompletion});

  final MealDialogState? initialState;
  final Completer<bool>? saveCompletion;
  int saves = 0;
  int cancelledNotifications = 0;
  int pendingReminderCancellations = 0;

  @override
  MealDialogState build(int mId, MealDialogStep initialStep) {
    mealId = mId;
    return initialState ?? MealDialogState.initial(initialStep);
  }

  @override
  Future<void> cancelAllMealNotifications() async {
    cancelledNotifications++;
  }

  @override
  Future<void> cancelPendingAdviceReminder() async {
    pendingReminderCancellations++;
  }

  @override
  Future<bool> confirmAdvice() {
    saves++;
    return saveCompletion?.future ?? Future.value(true);
  }
}
