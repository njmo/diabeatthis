import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_handoff_repository.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late drift.DatabaseImpl db;
  final savedAt = DateTime.utc(2026, 9, 28, 12);
  var treatmentSequence = 0;

  setUp(() => db = drift.DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> recordedTreatment(double carbs) async {
    final meal = await db.mealDao.createLowTreatmentEntry(
      name: 'Low treatment ${treatmentSequence++}',
      eatenAt: savedAt,
    );
    final ingredientId = await db
        .into(db.ingredient)
        .insert(
          drift.IngredientCompanion.insert(
            name: 'Glucose',
            carbsPer100g: 100,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
          ),
        );
    await db
        .into(db.mealIngredients)
        .insert(
          drift.MealIngredientsCompanion.insert(
            mealId: meal.id,
            ingredientId: ingredientId,
            amount: Value(carbs),
            consumedAmount: Value(carbs),
            quantityConfidence: 1,
          ),
        );
    return meal.id;
  }

  LowTreatmentHandoffUseCase useCase(TreatmentsHistoryRepository history) {
    final recorded = RecordedLowTreatmentRepository(db);
    return LowTreatmentHandoffUseCase(
      handoffs: LowTreatmentHandoffRepository(db),
      loadRecordedCarbs: (mealId) async =>
          (await recorded.fetchByMealId(mealId))?.netCarbsGrams,
      loadHistory: () async => history,
    );
  }

  test(
    'registers actual carbs, links a unique Treat and survives restart',
    () async {
      final mealId = await recordedTreatment(12);
      final suggestionAt = savedAt.subtract(const Duration(minutes: 1));
      final treat = Treat(
        externalId: 'remote-1',
        createdAt: savedAt.add(const Duration(minutes: 2)),
        carbs: 12,
      );
      final first = useCase(_History([treat]));
      await first.registerPending(
        mealId: mealId,
        savedAt: savedAt,
        suggestionAt: suggestionAt,
      );

      final match = (await first.reconcile(
        now: savedAt.add(const Duration(minutes: 3)),
      )).single;
      expect(match.mealId, mealId);
      expect(
        match.suggestionAt?.millisecondsSinceEpoch,
        suggestionAt.millisecondsSinceEpoch,
      );
      expect(
        (await db.select(db.lowTreatmentReview).get()).single.mealId,
        mealId,
      );

      final restarted = useCase(_ThrowingHistory());
      expect(
        (await restarted.reconcile(
          now: savedAt.add(const Duration(minutes: 4)),
        )).single.treatExternalId,
        'remote-1',
      );
      await restarted.markCompleted(mealId);
      expect(await restarted.hasPending(), isFalse);
    },
  );

  test('live Treat reconciles when selected history is unavailable', () async {
    final mealId = await recordedTreatment(8);
    final handoff = useCase(_ThrowingHistory());
    await handoff.registerPending(
      mealId: mealId,
      savedAt: savedAt,
      suggestionAt: null,
    );
    final live = Treat(
      externalId: null,
      createdAt: savedAt.add(const Duration(minutes: 1)),
      carbs: 8,
    );
    expect(
      await handoff.reconcile(
        now: savedAt.add(const Duration(minutes: 2)),
        liveTreatments: [live],
      ),
      hasLength(1),
    );
  });

  test(
    'ambiguous matches and prior manual decisions remain untouched',
    () async {
      final firstMeal = await recordedTreatment(10);
      final secondMeal = await recordedTreatment(10);
      final events = [
        Treat(
          externalId: 'one',
          createdAt: savedAt.add(const Duration(minutes: 1)),
          carbs: 10,
        ),
        Treat(
          externalId: 'two',
          createdAt: savedAt.add(const Duration(minutes: 2)),
          carbs: 10,
        ),
      ];
      final handoff = useCase(_History(events));
      await handoff.registerPending(
        mealId: firstMeal,
        savedAt: savedAt,
        suggestionAt: null,
      );
      await handoff.registerPending(
        mealId: secondMeal,
        savedAt: savedAt,
        suggestionAt: null,
      );
      expect(
        await handoff.reconcile(now: savedAt.add(const Duration(minutes: 5))),
        isEmpty,
      );
      expect(await db.select(db.lowTreatmentReview).get(), isEmpty);

      await db
          .into(db.lowTreatmentReview)
          .insert(
            drift.LowTreatmentReviewCompanion.insert(
              occurredAt: Value(events.first.createdAt.millisecondsSinceEpoch),
              externalId: const Value('one'),
              dismissed: const Value(true),
            ),
          );
      expect(
        await handoff.reconcile(now: savedAt.add(const Duration(minutes: 5))),
        isEmpty,
      );
      expect(
        (await db.select(db.lowTreatmentReview).get()).single.dismissed,
        true,
      );
    },
  );
}

class _History implements TreatmentsHistoryRepository {
  final List<Treatment> treatments;
  const _History(this.treatments);

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async => treatments;

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}

class _ThrowingHistory implements TreatmentsHistoryRepository {
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) => throw StateError('offline');

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}
