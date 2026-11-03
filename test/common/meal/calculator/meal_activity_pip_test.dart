import 'dart:convert';

import 'package:diabeatthis/common/l10n/generated/app_localizations_en.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations_pl.dart';
import 'package:diabeatthis/common/meal/calculator/calculator_instruction_event.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/common/meal/calculator/meal_handoff_instruction.dart';
import 'package:diabeatthis/common/meal/meal_decision.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/domain/events/meal_suggestion_notification.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 11, 3, 14);
  MealActivityDoseSuggestion suggestion({
    int percent = 80,
    MealActivityPhase phase = MealActivityPhase.upcoming,
  }) => MealActivityDoseSuggestion(
    dosePercent: percent,
    activityName: 'Walk',
    startedAt: at,
    phase: phase,
  );
  AapsBolusSuggestionNotificationEvent event({
    int percent = 80,
    bool extended = true,
  }) => AapsBolusSuggestionNotificationEvent(
    mealId: 7,
    carbs: 45,
    activityDoseSuggestion: suggestion(percent: percent),
    extendedCarbs: extended ? 12 : 0,
    extendedCarbsDelayMinutes: extended ? 45 : null,
    extendedCarbsDurationMinutes: extended ? 120 : null,
  );

  test(
    'notification conversion and actual JSON round trip preserve suggestion',
    () {
      final original = MealSuggestionNotificationEvent(
        mealId: 7,
        minutes: 0,
        decision: MealDecision.bolusAndEatNow,
        carbs: 45,
        activityDoseSuggestion: suggestion(),
      );
      final restored = MealSuggestionNotificationEvent.fromPayload(
        jsonDecode(jsonEncode(original.toJson())),
      );
      final converted = calculatorInstructionEvent(restored)!;
      expect(converted.activityDoseSuggestion, suggestion());
      final pip = AapsBolusSuggestionNotificationEvent.fromPayload(
        jsonDecode(jsonEncode(converted.toJson())),
      );
      expect(pip.activityDoseSuggestion, suggestion());
    },
  );

  test(
    'carb corrections and eCarbs-only instructions never show a bolus percentage',
    () {
      for (final carbs in [-20, 0]) {
        final correction = AapsBolusSuggestionNotificationEvent(
          carbs: carbs,
          extendedCarbs: 12,
          extendedCarbsDelayMinutes: 45,
          extendedCarbsDurationMinutes: 120,
          activityDoseSuggestion: suggestion(),
        );
        final instruction = MealHandoffInstruction.build(
          correction,
          AppLocalizationsPl(),
        );
        expect(instruction.steps, hasLength(3));
        expect(instruction.steps.any((s) => s.label.contains('80%')), isFalse);
        expect(
          MealCalculatorRequest(event: correction, openedAt: at).completedRows,
          hasLength(3),
        );
      }
    },
  );

  test('old events without the optional field remain supported', () {
    final restored = AapsBolusSuggestionNotificationEvent.fromPayload({
      'carbs': 45,
    });
    expect(restored.activityDoseSuggestion, isNull);
    expect(
      MealHandoffInstruction.build(restored, AppLocalizationsPl()).steps,
      hasLength(1),
    );
  });

  test('invalid transported percentages are ignored', () {
    for (final percent in [0, -10, 101, '80']) {
      final json = suggestion().toJson()..['dosePercent'] = percent;
      expect(MealActivityDoseSuggestion.fromJson(json), isNull);
    }
  });

  test(
    'PiP displays percent of dose, phase and activity without a checkbox',
    () {
      final instruction = MealHandoffInstruction.build(
        event(),
        AppLocalizationsPl(),
      );
      expect(instruction.steps.map((s) => s.label), [
        'Carbs',
        'Propozycja: 80% dawki',
        'E-carbs',
      ]);
      expect(instruction.steps[1].value, 'Posiłek przed aktywnością · Walk');
      expect(instruction.steps[2].value, '12 g · za 45 min przez 2 godz.');
      expect(instruction.steps[1].showCheckbox, isFalse);
      expect(instruction.steps[1].actionId, MealHandoffInstruction.bolusAction);
      final en = MealHandoffInstruction.build(event(), AppLocalizationsEn());
      expect(en.steps[1].label, 'Suggestion: 80% of the dose');
    },
  );

  test('all phases are distinct in the instruction', () {
    for (final phase in MealActivityPhase.values) {
      final instruction = MealHandoffInstruction.build(
        AapsBolusSuggestionNotificationEvent(
          carbs: 45,
          activityDoseSuggestion: suggestion(phase: phase),
        ),
        AppLocalizationsPl(),
      );
      expect(instruction.steps[1].value, switch (phase) {
        MealActivityPhase.upcoming => 'Posiłek przed aktywnością · Walk',
        MealActivityPhase.ongoing => 'Aktywność w trakcie · Walk',
        MealActivityPhase.completed => 'Posiłek po treningu · Walk',
      });
    }
  });

  test(
    'persisted PiP request keeps suggestion and matches instruction row count',
    () {
      final request = MealCalculatorRequest(
        event: event(),
        openedAt: at,
        sessionId: 'pip',
      );
      final restored = MealCalculatorRequest.fromJson(
        jsonDecode(jsonEncode(request.toJson())),
      );
      expect(restored.event.activityDoseSuggestion, suggestion());
      final instruction = MealHandoffInstruction.build(
        restored.event,
        AppLocalizationsPl(),
      );
      expect(restored.completedRows, hasLength(instruction.steps.length));
      expect(restored.progress.actions.keys, [
        MealHandoffInstruction.bolusAction,
        MealHandoffInstruction.extendedCarbsAction,
      ]);
    },
  );

  test(
    'controller replaces proposal on explicit reopen and preserves dose evidence',
    () async {
      final store = MemoryMealCalculatorRequestStore();
      final windows = <List<bool>>[];
      final controller = MealCalculatorRequestController(
        store: store,
        now: () => at,
        publishWindow: (_, rows) async {
          windows.add(rows);
        },
        readContext: (_) async => null,
        projectExtendedConfirmation: (_, _, _, _) async {},
        onError: (error, _) => fail('$error'),
      );
      addTearDown(controller.dispose);
      await controller.register(event(), sessionId: 'pip', openedAt: at);
      await controller.observe({
        'submissions': [
          {
            'at': at.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
            'carbs': 45,
            'valid': true,
            'complete': true,
          },
        ],
      });
      await controller.register(event(percent: 70));
      expect(
        MealCalculatorRequest.fromJson(
          store.requests.single,
        ).event.activityDoseSuggestion!.dosePercent,
        80,
      );
      await controller.register(event(percent: 70), sessionId: 'pip-reopened');
      final restored = MealCalculatorRequest.fromJson(store.requests.single);
      expect(restored.event.activityDoseSuggestion!.dosePercent, 70);
      expect(restored.sessionId, 'pip-reopened');
      expect(restored.openedAt, at);
      expect((restored.tracker.evidence['submissions'] as List), hasLength(1));
      expect(windows.last, [true, true, false]);
    },
  );

  test(
    'informational row adds no confirmation requirement without eCarbs',
    () async {
      final request = MealCalculatorRequest(
        event: event(extended: false),
        openedAt: at,
      );
      expect(request.progress.actions.keys, [
        MealHandoffInstruction.bolusAction,
      ]);
      expect(request.completedRows, [false, false]);
    },
  );
}
