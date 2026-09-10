import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/check_meal_advice_eligibility_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/check_meal_advice_eligibility_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class EligibilityHistoryRepository implements GlucoseHistoryRepository {
  List<Glucose> readings = [];
  DateTime? requestedStart;
  DateTime? requestedEnd;
  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    requestedStart = start;
    requestedEnd = end;
    return readings;
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) =>
      throw UnimplementedError();
}

void main() {
  final now = DateTime(2026, 9, 9, 12);
  Glucose sample(int seconds, {GlucoseType type = GlucoseType.cgm}) => Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: now.subtract(Duration(seconds: seconds)),
    sgv: 120,
    direction: '',
    type: type,
  );
  final repository = EligibilityHistoryRepository();
  final useCase = CheckMealAdviceEligibilityUseCase(
    loadRepository: () async => repository,
  );

  test('accepts three consecutive readings with latest under ten minutes', () {
    expect(
      useCase.evaluate([sample(1199), sample(899), sample(599)], now),
      MealAdviceEligibility.available,
    );
    expect(
      useCase.evaluate([sample(1200), sample(900), sample(600)], now),
      MealAdviceEligibility.staleReadings,
    );
  });
  test(
    'sorts and deduplicates; finger and future samples cannot fill gaps',
    () {
      expect(
        useCase.evaluate([
          sample(0),
          sample(600),
          sample(300),
          sample(300),
        ], now),
        MealAdviceEligibility.available,
      );
      expect(
        useCase.evaluate([
          sample(0),
          sample(300),
          sample(300),
          sample(600, type: GlucoseType.finger),
          sample(-300),
        ], now),
        MealAdviceEligibility.insufficientReadings,
      );
    },
  );
  test('requires consecutive latest readings with cadence tolerance', () {
    expect(
      useCase.evaluate([sample(900), sample(300), sample(0)], now),
      MealAdviceEligibility.discontinuousReadings,
    );
    expect(
      useCase.evaluate([sample(2), sample(1), sample(0)], now),
      MealAdviceEligibility.discontinuousReadings,
    );
    expect(
      useCase.evaluate([sample(600), sample(360), sample(0)], now),
      MealAdviceEligibility.available,
    );
  });
  test(
    'uses configured history provider and refreshes on each check',
    () async {
      final container = ProviderContainer(
        overrides: [
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
        ],
      );
      addTearDown(container.dispose);
      await withClock(Clock.fixed(now), () async {
        repository.readings = [sample(600), sample(300), sample(0)];
        final check = container.read(checkMealAdviceEligibilityUseCaseProvider);
        expect(await check(), MealAdviceEligibility.available);
        expect(
          repository.requestedStart,
          now.subtract(const Duration(minutes: 30)),
        );
        expect(repository.requestedEnd, now);
        repository.readings = [];
        expect(await check(), MealAdviceEligibility.insufficientReadings);
      });
    },
  );
  test('repository failure and timeout make advice unavailable', () async {
    final failing = CheckMealAdviceEligibilityUseCase(
      loadRepository: () async => throw Exception('offline'),
    );
    expect(await failing(), MealAdviceEligibility.historyUnavailable);
    final delayed = CheckMealAdviceEligibilityUseCase(
      loadRepository: () =>
          Future.delayed(const Duration(milliseconds: 20), () => repository),
      timeout: const Duration(milliseconds: 1),
    );
    expect(await delayed(), MealAdviceEligibility.historyUnavailable);
  });
}
