import 'package:diabeatthis/common/meal/calculator/calculator_evidence_snapshot.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_evidence.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 11, 3, 13, 18);
  const event = AapsBolusSuggestionNotificationEvent(mealId: 7, carbs: -2);
  Map<String, dynamic> receipt({
    int carbs = -2,
    int seconds = 13,
    int duration = 0,
    bool valid = true,
  }) => {
    'id': 'correction',
    'at': opened.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
    'carbs': carbs,
    'duration': duration,
    'valid': valid,
  };

  for (final hasDuration in [false, true]) {
    test(
      'AAPS carb correction closes without a wizard (duration field: $hasDuration)',
      () async {
        final windows = <List<bool>>[];
        var completed = 0;
        final store = MemoryMealCalculatorRequestStore();
        MealCalculatorRequestController controller() =>
            MealCalculatorRequestController(
              store: store,
              now: () => opened.add(const Duration(seconds: 14)),
              readContext: (_) async => null,
              projectExtendedConfirmation: (_, _, _, _) async {},
              publishWindow: (_, rows) async {
                windows.add(rows);
              },
              onComplete: (_) async {
                completed++;
              },
              onError: (error, _) => fail('$error'),
            );
        final owner = controller();
        await owner.register(event, sessionId: 'negative', openedAt: opened);
        expect(windows.last, [false]);
        final treatment = TreatmentFactory().parseTreatments([
          {
            'eventType': 'Carb Correction',
            '_id': '66',
            'carbs': -2,
            'created_at': opened
                .add(const Duration(seconds: 13))
                .toUtc()
                .toIso8601String(),
            if (hasDuration) 'duration': 0,
          },
        ]).single;
        final snapshot = CalculatorEvidenceSnapshot(
          [],
          treatment is ExtendedCarb ? treatment : null,
          carbCorrection: treatment is Treat ? treatment : null,
        );
        await owner.observe(snapshot.toJson());
        expect(windows.last, [true]);
        expect(completed, 1);
        owner.dispose();
        final restored = controller();
        await restored.refresh();
        expect(windows.last, [true]);
        expect(completed, 1);
        await restored.register(
          event,
          sessionId: 'next-negative',
          openedAt: opened.add(const Duration(minutes: 1)),
        );
        expect(windows.last, [false]);
        restored.dispose();
      },
    );
  }

  test(
    'wrong sign, amount, time, extended entry and invalid entries do not confirm a negative correction',
    () {
      for (final row in [
        receipt(carbs: 2),
        receipt(carbs: -3),
        receipt(seconds: -1),
        receipt(seconds: 1201),
        receipt(duration: 7200000),
        receipt(valid: false),
      ]) {
        final tracker = MealCalculatorEvidence(event: event, openedAt: opened);
        expect(
          tracker.update({'submissions': [], 'extendedCarb': row}),
          isFalse,
        );
      }
      final tracker = MealCalculatorEvidence(event: event, openedAt: opened);
      expect(
        tracker.update({
          'submissions': [
            {
              'at': opened.millisecondsSinceEpoch,
              'carbs': -2,
              'valid': true,
              'complete': true,
            },
          ],
        }),
        isFalse,
      );
      expect(
        tracker.update({'submissions': [], 'extendedCarb': receipt()}),
        isTrue,
      );
      expect(
        tracker.update({
          'submissions': [],
          'extendedCarb': receipt(valid: false),
        }),
        isFalse,
      );
    },
  );

  test(
    'a saved ordinary correction can be recovered without a live wizard event',
    () async {
      final windows = <List<bool>>[];
      final owner = MealCalculatorRequestController(
        store: MemoryMealCalculatorRequestStore(),
        now: () => opened,
        readContext: (_) async => null,
        readExtendedReceipts: (_, _) async => [receipt()],
        projectExtendedConfirmation: (_, _, _, _) async {},
        publishWindow: (_, rows) async {
          windows.add(rows);
        },
        onError: (error, _) => fail('$error'),
      );
      await owner.register(event, sessionId: 'saved', openedAt: opened);
      expect(windows.last, [true]);
      owner.dispose();
    },
  );

  test('positive carbs still require calculator completion', () {
    final tracker = MealCalculatorEvidence(
      event: const AapsBolusSuggestionNotificationEvent(carbs: 2),
      openedAt: opened,
    );
    expect(
      tracker.update({'submissions': [], 'extendedCarb': receipt(carbs: 2)}),
      isFalse,
    );
  });
}
