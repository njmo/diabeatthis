import 'package:diabeatthis/common/meal/calculator/calculator_evidence_snapshot.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_store.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mealInsulin in [0.0, 1.5]) {
    test(
      'AAPS advisor insulin alone cannot confirm the later meal (meal insulin: $mealInsulin)',
      () async {
        final opened = DateTime(2026, 11, 3, 15);
        final container = ProviderContainer();
        final rows = <List<bool>>[];
        final owner = MealCalculatorRequestController(
          store: MemoryMealCalculatorRequestStore(),
          now: () => opened,
          readContext: (_) async => null,
          projectExtendedConfirmation: (_, _, _, _) async {},
          publishWindow: (_, state) async {
            rows.add(state);
          },
          onError: (error, _) => fail('$error'),
        );
        addTearDown(() {
          owner.dispose();
          container.dispose();
        });
        await owner.register(
          const AapsBolusSuggestionNotificationEvent(
            mealId: 7,
            carbs: 10,
            extendedCarbs: 15,
            extendedCarbsDelayMinutes: 45,
            extendedCarbsDurationMinutes: 120,
          ),
          sessionId: 'advisor',
          openedAt: opened,
        );
        final factory = TreatmentFactory();
        String iso(DateTime at) => at.toUtc().toIso8601String();
        // AAPS BS.toJson exports NORMAL insulin as Meal Bolus, even when its
        // command was BOLUS_ADVISOR. No BCR or carbohydrates are persisted here.
        final correction = factory.parseTreatments([
          {
            'eventType': 'Meal Bolus',
            'type': 'NORMAL',
            'isSMB': false,
            'insulin': 1.5,
            'created_at': iso(opened.add(const Duration(seconds: 10))),
          },
        ]).single;
        expect(correction, isA<ManualBolus>());
        container
            .read(calculatorSubmissionsProvider.notifier)
            .record(correction);
        expect(container.read(calculatorSubmissionsProvider), isEmpty);
        await owner.observe(
          CalculatorEvidenceSnapshot(
            container.read(calculatorSubmissionsProvider),
            null,
          ).toJson(),
        );
        expect(rows.last, [false, false, false]);
        final mealAt = opened.add(const Duration(minutes: 5));
        final mealRecords = factory.parseTreatments([
          {
            'eventType': 'Bolus Wizard',
            'created_at': iso(mealAt),
            'glucose': 140,
            'bolusCalculatorResult': {'carbs': 10, 'totalInsulin': mealInsulin},
          },
          {
            'eventType': 'Meal Bolus',
            'created_at': iso(mealAt.add(const Duration(seconds: 1))),
            'carbs': 10,
          },
        ]);
        for (final record in mealRecords) {
          container.read(calculatorSubmissionsProvider.notifier).record(record);
        }
        expect(
          container.read(calculatorSubmissionsProvider).single.wizard,
          isA<BolusWizard>(),
        );
        expect(
          container.read(calculatorSubmissionsProvider).single.delivery,
          isNull,
        );
        expect(
          container.read(calculatorSubmissionsProvider).single.isComplete,
          mealInsulin == 0,
        );
        if (mealInsulin > 0) {
          final delivery = factory.parseTreatments([
            {
              'eventType': 'Meal Bolus',
              'created_at': iso(mealAt.add(const Duration(seconds: 2))),
              'insulin': mealInsulin,
            },
          ]).single;
          container
              .read(calculatorSubmissionsProvider.notifier)
              .record(delivery);
          expect(
            container.read(calculatorSubmissionsProvider).single.delivery,
            delivery,
          );
        }
        await owner.observe(
          CalculatorEvidenceSnapshot(
            container.read(calculatorSubmissionsProvider),
            null,
          ).toJson(),
        );
        expect(rows.last, [true, false, false]);
        final extended =
            factory.parseTreatments([
                  {
                    'eventType': 'Carb Correction',
                    'created_at': iso(mealAt.add(const Duration(minutes: 45))),
                    'carbs': 15,
                    'duration': const Duration(hours: 2).inMilliseconds,
                  },
                ]).single
                as ExtendedCarb;
        await owner.observe(
          CalculatorEvidenceSnapshot(
            container.read(calculatorSubmissionsProvider),
            extended,
          ).toJson(),
        );
        expect(rows.last, [true, true, true]);
      },
    );
  }
}
