import 'package:clock/clock.dart';
import 'package:diabeatthis/common/monitoring/meal_wait_status.dart';
import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/domain/model/bolus_calculator_result.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_progress_history_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_progress_history.dart';
import 'package:diabeatthis/features/meals/domain/models/meal_ecarbs_proposal.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_progress_now.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_progress_now_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

class _Treatments implements TreatmentsHistoryRepository {
  _Treatments(this.records);

  final List<Treatment> records;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async => records;

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}

final _planned = DateTime(2026, 11, 27, 20, 56);

MealDetailsData _details(String status, List<(String, DateTime)> history) =>
    MealDetailsData(
      meal: MealRecordData(
        id: 1,
        name: 'QM: żurek',
        status: status,
        plannedAt: _planned,
        summarizedAt: null,
        mealTemplateId: null,
        basedOnMealId: null,
        notes: null,
        createdAt: _planned,
        updatedAt: _planned,
        isSynced: false,
      ),
      advisorDecision: MealAdvisorDecisionData(
        result: 'bolused-waiting',
        initialWaitTime: 15,
        finalWaitTime: 15,
        waitTimeIgnored: false,
        extendedCarbsGrams: 25,
        extendedCarbsDeliveryMode: 'extendedCarbs',
        extendedCarbsDelayMinutes: 45,
        extendedCarbsDurationMinutes: 120,
        decisionReason: null,
        version: 1,
        isSynced: false,
        createdAt: _planned,
        updatedAt: _planned,
      ),
      ingredients: const [],
      plannedSnapshot: null,
      consumedSnapshot: null,
      statusHistory: [
        for (final (index, (entry, at)) in history.indexed)
          MealStatusHistoryEntryData(
            id: index,
            mealId: 1,
            status: entry,
            createdAt: at,
          ),
      ],
    );

BolusWizard _calculator(DateTime at, double carbs) => BolusWizard(
  nightscoutObjectId: null,
  createdAt: at,
  date: at,
  glucose: 170,
  units: 'mg/dL',
  notes: null,
  calculatorResult: BolusCalculatorResult(
    id: null,
    basalIob: null,
    bolusIob: null,
    carbs: carbs,
    carbsInsulin: null,
    cob: null,
    cobInsulin: null,
    dateCreated: null,
    glucoseDifference: null,
    glucoseInsulin: null,
    glucoseTrend: null,
    glucoseValue: null,
    ic: null,
    isf: null,
    note: null,
    otherCorrection: null,
    percentageCorrection: null,
    profileName: null,
    superbolusInsulin: null,
    targetBGHigh: null,
    targetBGLow: null,
    timestamp: null,
    totalInsulin: 1.5,
    trendInsulin: null,
    utcOffset: null,
    version: null,
    wasBasalIOBUsed: null,
    wasBolusIOBUsed: null,
    wasCOBUsed: null,
    wasGlucoseUsed: null,
    wasSuperbolusUsed: null,
    wasTempTargetUsed: null,
    wasTrendUsed: null,
    wereCarbsUsed: null,
  ),
);

ExtendedCarb _ecarbs(DateTime start, {int minutes = 120}) => ExtendedCarb(
  externalId: 'e',
  createdAt: start,
  carbs: 25,
  duration: Duration(minutes: minutes).inMilliseconds,
);

const _proposal = MealEcarbsProposal(
  hasDecision: true,
  kind: MealEcarbsProposalKind.extendedCarbs,
  grams: 25,
  delayMinutes: 45,
  durationMinutes: 120,
);

void main() {
  final calculatorAt = _planned;
  final bolusAt = _planned.add(const Duration(minutes: 1));
  final waiting = _details('bolused-waiting', [
    ('planned', _planned.subtract(const Duration(hours: 1))),
    ('waiting-for-bolus', _planned),
    ('bolused-waiting', bolusAt),
  ]);

  MealProgressNow progress(List<ExtendedCarb> ecarbs) => MealProgressNow.from(
    details: waiting,
    history: MealProgressHistory(
      calculators: [_calculator(calculatorAt, 15)],
      extendedCarbs: ecarbs,
    ),
    proposal: _proposal,
  );

  test('a forgotten eCarbs entry is shown as missing with its start', () {
    final now = progress(const []);

    expect(now.calculator?.carbs, 15);
    expect(now.bolusAt, bolusAt);
    expect(now.waitEndsAt, bolusAt.add(const Duration(minutes: 15)));
    expect(now.extendedCarbs?.entered, isNull);
    expect(
      now.extendedCarbs?.expectedStart,
      calculatorAt.add(const Duration(minutes: 45)),
    );
  });

  test('eCarbs entered within the start window count for the meal', () {
    final expected = calculatorAt.add(const Duration(minutes: 45));

    expect(
      progress([
        _ecarbs(expected.add(const Duration(minutes: 9))),
      ]).extendedCarbs?.entered,
      isNotNull,
    );
    expect(
      progress([
        _ecarbs(expected.add(const Duration(minutes: 11))),
      ]).extendedCarbs?.entered,
      isNull,
    );
    expect(
      progress([_ecarbs(expected, minutes: 60)]).extendedCarbs?.entered,
      isNull,
    );
  });

  test('eCarbs with fewer grams than planned are not entered yet', () {
    final expected = calculatorAt.add(const Duration(minutes: 45));
    final partial = ExtendedCarb(
      externalId: 'partial',
      createdAt: expected,
      carbs: 10,
      duration: const Duration(minutes: 120).inMilliseconds,
    );

    expect(progress([partial]).extendedCarbs?.entered, isNull);
  });

  test('skipping eCarbs is offered only after the recommended wait', () {
    final deadline = bolusAt.add(const Duration(minutes: 15));
    final wait = (
      mealId: 1,
      startedAt: bolusAt,
      deadline: deadline,
      waitingForExtendedCarbs: true,
    );

    expect(
      mealWaitHeldByExtendedCarbs(
        wait,
        1,
        deadline.subtract(const Duration(minutes: 1)),
      ),
      isFalse,
    );
    expect(mealWaitHeldByExtendedCarbs(wait, 1, deadline), isTrue);
    expect(mealWaitHeldByExtendedCarbs(wait, 2, deadline), isFalse);
  });

  test('a calculator from before the meal is not taken as its own', () {
    final now = MealProgressNow.from(
      details: waiting,
      history: MealProgressHistory(
        calculators: [
          _calculator(_planned.subtract(const Duration(minutes: 30)), 10),
        ],
        extendedCarbs: const [],
      ),
      proposal: _proposal,
    );

    expect(now.calculator, isNull);
  });

  testWidgets('the now card tells what a forgotten eCarbs meal waits for', (
    tester,
  ) async {
    await withClock(
      Clock.fixed(_planned.add(const Duration(minutes: 80))),
      () async {
        await tester.pumpWidget(
          ProviderScope(
            child: localizedMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MealProgressNowCard(progress: progress(const [])),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      },
    );

    expect(find.text('Teraz'), findsOneWidget);
    expect(find.text('Czekamy na eCarbs w AAPS'), findsOneWidget);
    expect(find.text('Kalkulator 15 g'), findsOneWidget);
    expect(find.text('20:56'), findsOneWidget);
    expect(find.text('20:57'), findsOneWidget);
    expect(find.text('do 21:12'), findsOneWidget);
    expect(find.text('eCarbs 25 g przez 120 min'), findsOneWidget);
    expect(find.text('brak'), findsOneWidget);
    expect(find.text('planowany start ok. 21:41'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('LoadMealProgressHistoryUseCase', () {
    test('reads only meals that are in progress', () async {
      final repository = _Treatments([
        _calculator(calculatorAt, 15),
        _calculator(calculatorAt, 0),
        _ecarbs(calculatorAt.add(const Duration(minutes: 45))),
      ]);
      final useCase = LoadMealProgressHistoryUseCase(
        repository: () async => repository,
      );

      final history = await useCase(waiting);
      expect(history?.calculators.map((wizard) => wizard.carbs), [15]);
      expect(history?.extendedCarbs, hasLength(1));
      expect(await useCase(_details('summarized', const [])), isNull);
      expect(await useCase(_details('planned', const [])), isNull);
    });
  });
}
