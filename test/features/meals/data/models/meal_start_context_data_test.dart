import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_start_context_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment;

void main() {
  final base = mealDetailsWithLowTreatment();
  final reference = base.meal.analysisTime;
  MealStatusHistoryEntryData status(String value, int minute) =>
      MealStatusHistoryEntryData(
        id: minute,
        mealId: 1,
        status: value,
        createdAt: reference.add(Duration(minutes: minute)),
      );
  test('eating period uses the first completion, not later add-ons', () {
    final details = base.copyWith(
      statusHistory: [
        status('eaten-extra', 45),
        status('eaten', 20),
        status('eating', 0),
        status('summarized', 60),
      ],
    );
    expect(details.recordedEatingStartedAt, reference);
    expect(
      details.recordedEatingEndedAt,
      reference.add(const Duration(minutes: 20)),
    );
  });

  test('eating before bolus ends when the meal starts waiting for bolus', () {
    final details = base.copyWith(
      statusHistory: [
        status('eating-then-bolus', 0),
        status('waiting-for-bolus', 15),
        status('eaten-bolused', 30),
      ],
    );
    expect(
      details.recordedEatingEndedAt,
      reference.add(const Duration(minutes: 15)),
    );
  });

  test('missing or inconsistent eating timestamps remain unknown', () {
    expect(
      base.copyWith(statusHistory: [status('eaten', 20)]).recordedEatingEndedAt,
      isNull,
    );
    expect(
      base
          .copyWith(
            statusHistory: [status('eating', 0), status('summarized', 20)],
          )
          .recordedEatingEndedAt,
      isNull,
    );
    expect(
      base
          .copyWith(statusHistory: [status('eaten', -5), status('eating', 0)])
          .recordedEatingEndedAt,
      isNull,
    );
  });

  MealAnalysisData history() => MealAnalysisData(
    chartStart: reference.subtract(const Duration(hours: 1)),
    chartEnd: reference.add(const Duration(hours: 6)),
    expectedChartEnd: reference.add(const Duration(hours: 6)),
    eventStart: reference.subtract(const Duration(hours: 1)),
    eventEnd: reference.add(const Duration(hours: 6)),
    mealTime: reference,
    glucoseReadings: [
      Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: reference.subtract(const Duration(minutes: 20)),
        sgv: 110,
        direction: 'FortyFiveDown',
      ),
    ],
    treatments: [
      ManualBolus(
        externalId: 'recorded',
        createdAt: reference.subtract(const Duration(minutes: 35)),
        insulin: 1.2,
      ),
      ManualBolus(
        externalId: 'after',
        createdAt: reference.add(const Duration(minutes: 5)),
        insulin: 2,
      ),
    ],
    temporaryTargets: const [],
    deviceStatuses: const [],
    linkedActivities: const [],
    linkedMeals: const [],
    timelineEvents: const [],
  );

  test('recorded start precedes summary and uses only the preceding bolus', () {
    final details = base.copyWith(
      statusHistory: [
        status('summarized', 0),
        status('eating-extra', -5),
        status('waited-eating', -20),
        status('bolused-waiting', -33),
      ],
    );
    final context = MealStartContextData(details: details, analysis: history());
    expect(
      details.analysisTime,
      reference.subtract(const Duration(minutes: 20)),
    );
    expect(context.bolusToStart, const Duration(minutes: 15));
    expect(context.recordedWait, const Duration(minutes: 13));
    expect(context.precedingBolus?.insulin, 1.2);
    expect(context.glucose?.direction, 'FortyFiveDown');
    expect(context.deviceStatus, isNull);
  });

  test('missing start does not turn summary time into actual waiting', () {
    final context = MealStartContextData(details: base, analysis: history());
    expect(context.hasRecordedStart, isFalse);
    expect(context.referenceTime, reference);
    expect(context.bolusToStart, isNull);
    expect(context.recordedWait, isNull);
    expect(context.glucose, isNull);
  });

  test('extra eating does not establish the initial start', () {
    final details = base.copyWith(statusHistory: [status('eating-extra', -5)]);
    expect(details.recordedEatingStartedAt, isNull);
  });
}
