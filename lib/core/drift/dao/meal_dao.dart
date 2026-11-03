import 'dart:async';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import '../../../common/meal/meal_add_on_bolus_progress.dart';
import '../../domain/model/meal_status_flow.dart';
import '../database_impl.dart';

part 'meal_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/meal.drift'})
class MealDao extends DatabaseAccessor<DatabaseImpl> with _$MealDaoMixin {
  MealDao(super.db);

  Future<void> updateMealStatus(
    int id,
    String status, {
    DateTime? occurredAt,
  }) async {
    // History maintenance retains its existing completed-status rewrite API.
    // Workflow callers use tryUpdateMealStatus to reject delayed transitions.
    await _writeMealStatus(
      id,
      status,
      occurredAt: occurredAt,
      allowCompletedStatusChange: true,
    );
  }

  /// Delayed workflow writes must not reactivate a deliberately stopped meal.
  Future<bool> tryUpdateMealStatus(
    int id,
    String status, {
    DateTime? occurredAt,
  }) => _writeMealStatus(
    id,
    status,
    occurredAt: occurredAt,
    allowCompletedStatusChange: false,
  );

  Future<bool> _writeMealStatus(
    int id,
    String status, {
    DateTime? occurredAt,
    required bool allowCompletedStatusChange,
  }) async {
    return transaction(() async {
      final current = await getMealById(id);
      if (current == null ||
          (current.status == 'interrupted' && status != 'interrupted') ||
          (!allowCompletedStatusChange &&
              current.purpose == 'meal' &&
              current.status == 'summarized' &&
              status != 'summarized' &&
              status != 'eating-extra')) {
        return false;
      }
      if (occurredAt != null) {
        // Historical confirmation replaces this status's time. Remove the old
        // slot before the status trigger inserts it again (unique meal/status).
        await (delete(
          db.mealStatusHistory,
        )..where((t) => t.mealId.equals(id) & t.status.equals(status))).go();
      }
      await (update(db.meal)..where((t) => t.id.equals(id))).write(
        MealCompanion(
          status: Value(status),
          addOnBolusContext:
              const {
                'planned',
                'skipped',
                'interrupted',
                'summarized',
              }.contains(status)
              ? const Value(null)
              : const Value.absent(),
          consumptionConfirmedEndedAt:
              status == 'waiting-for-bolus' || status == 'eaten-bolused'
              ? const Value.absent()
              : const Value(null),
        ),
      );
      if (occurredAt != null) {
        final timestamp = occurredAt.millisecondsSinceEpoch;
        // Also covers replaying the current status, when the trigger is idle.
        await into(db.mealStatusHistory).insert(
          MealStatusHistoryCompanion.insert(
            mealId: id,
            status: status,
            createdAt: Value(timestamp),
          ),
          onConflict: DoUpdate(
            (_) => MealStatusHistoryCompanion(createdAt: Value(timestamp)),
            target: [db.mealStatusHistory.mealId, db.mealStatusHistory.status],
          ),
        );
      }
      if (current.status == 'planned' && status == 'eating-then-bolus') {
        // A new food-first meal has not reported any eCarbs yet. Initialize
        // after the eating history time is final; legacy recovery keeps its
        // previous planned baseline and repeated status writes retain theirs.
        await reconcileMealAddOnBolusProgress(
          db,
          id,
          initialReportedExtendedCarbs: 0,
        );
      }
      if (occurredAt != null) {
        final timestamp = occurredAt.millisecondsSinceEpoch;
        await (update(db.meal)..where((t) => t.id.equals(id))).write(
          MealCompanion(
            updatedAt: Value(timestamp),
            summarizedAt: status == 'summarized'
                ? Value(timestamp)
                : const Value.absent(),
          ),
        );
      }
      return true;
    });
  }

  /// Only an explicit quantity confirmation for this waiting round can finish
  /// automatically once the bolus has been recorded.
  Future<bool> summarizeConfirmedMealAfterBolus(int mealId) => transaction(
    () async {
      final current = await getMealById(mealId);
      final confirmedEnd = current?.consumptionConfirmedEndedAt;
      if (current?.status != 'eaten-bolused' || confirmedEnd == null) {
        return false;
      }
      final waiting =
          await (select(db.mealStatusHistory)..where(
                (row) =>
                    row.mealId.equals(mealId) &
                    row.status.equals('waiting-for-bolus'),
              ))
              .getSingleOrNull();
      if (waiting?.createdAt != confirmedEnd) return false;
      final snapshot =
          await (select(db.mealSnapshot)..where(
                (row) =>
                    row.mealId.equals(mealId) &
                    row.snapshotType.equals('consumed'),
              ))
              .getSingleOrNull();
      if (snapshot == null) return false;
      final consumed = await db.ingredientDao.totalsForMealConsumed(mealId);
      if (consumed == null) return false;
      final quantities = [
        (current: consumed.totalGrams, confirmed: snapshot.totalGrams),
        (current: consumed.carbsGrams, confirmed: snapshot.totalCarbsG),
        (current: consumed.netCarbsGrams, confirmed: snapshot.totalNetCarbsG),
        (current: consumed.fiberGrams, confirmed: snapshot.totalFiberG),
        (current: consumed.proteinGrams, confirmed: snapshot.totalProteinG),
        (current: consumed.fatGrams, confirmed: snapshot.totalFatG),
        (current: consumed.totalKcal, confirmed: snapshot.totalCaloriesKcal),
      ];
      if (quantities.any(
        (value) =>
            !value.current.isFinite ||
            (value.current - value.confirmed).abs() > 0.001,
      )) {
        return false;
      }
      return tryUpdateMealStatus(mealId, 'summarized', occurredAt: clock.now());
    },
  );

  /// Corrects an observed eating event without replaying a workflow transition.
  Future<void> updateMealStatusHistoryTime(
    int mealId,
    String status,
    DateTime occurredAt,
  ) async {
    await transaction(() async {
      final current = await getMealById(mealId);
      if (current == null || current.status == 'interrupted') {
        throw StateError('The meal can no longer be completed.');
      }
      final history =
          await (select(db.mealStatusHistory)..where(
                (row) => row.mealId.equals(mealId) & row.status.equals(status),
              ))
              .getSingleOrNull();
      final confirmsEatingBeforeRecordedBolus =
          current.status == 'eaten-bolused' && status == 'eaten';
      if (history == null &&
          current.status != status &&
          !confirmsEatingBeforeRecordedBolus) {
        throw StateError('The recorded meal stage does not exist.');
      }
      await into(db.mealStatusHistory).insert(
        MealStatusHistoryCompanion.insert(
          mealId: mealId,
          status: status,
          createdAt: Value(occurredAt.millisecondsSinceEpoch),
        ),
        onConflict: DoUpdate(
          (_) => MealStatusHistoryCompanion(
            createdAt: Value(occurredAt.millisecondsSinceEpoch),
          ),
          target: [db.mealStatusHistory.mealId, db.mealStatusHistory.status],
        ),
      );
    });
  }

  Future<bool> interruptMeal(int id, {String? expectedStatus}) async {
    return transaction(() async {
      final current = await getMealById(id);
      if (current == null) return false;
      if (current.status == 'interrupted') return true;
      if (expectedStatus != null && current.status != expectedStatus) {
        return false;
      }
      if (current.status != 'planned' &&
          !mealStatusBlocksAnotherMealActivation(current.status)) {
        return false;
      }
      return tryUpdateMealStatus(id, 'interrupted');
    });
  }

  /// Called inside confirmation's transaction, before replaying confirmed eating.
  /// Planning and skipping remain as audit events, not active eating stages.
  Future<void> clearInterruptedEatingHistory(int mealId) async {
    // These are replayable eating stages, independent of monitor activation rules.
    const statuses = [
      'eating',
      'eating-extra',
      'eating-then-bolus',
      'waiting-for-bolus',
      'bolused-waiting',
      'waited-eating',
      'bolused-eating',
      'eaten',
      'eaten-extra',
      'eaten-bolused',
    ];
    await (delete(db.mealStatusHistory)..where(
          (row) => row.mealId.equals(mealId) & row.status.isIn(statuses),
        ))
        .go();
  }

  /// The optional name is accepted for legacy callers; only purpose identifies a low treatment.
  Future<MealData> createLowTreatmentEntry({
    String? name,
    required DateTime eatenAt,
    String? notes,
  }) => transaction(() async {
    return into(db.meal).insertReturning(
      MealCompanion.insert(
        name: '',
        plannedAt: eatenAt.millisecondsSinceEpoch,
        summarizedAt: Value(eatenAt.millisecondsSinceEpoch),
        purpose: const Value('lowTreatment'),
        status: const Value('confirmed'),
        notes: Value(notes),
      ),
    );
  });

  Stream<List<MealData>> getAllMealForToday() {
    final now = clock.now().toUtc();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    final query = select(db.meal)
      ..where(
        (tbl) =>
            tbl.plannedAt.isBiggerThanValue(todayMillisecondsSinceEpoch) |
            tbl.status.isIn(
              mealStatusesBlockingAnotherMealActivation.toList(growable: false),
            ),
      )
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Future<MealData?> getMealById(int id) async {
    final query = select(db.meal)..where((tbl) => tbl.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<void> deleteMealAndGeneratedData(int id) async {
    await transaction(() async {
      await (delete(
        db.mealAdvisorResult,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealSnapshot,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealIngredients,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (delete(
        db.mealStatusHistory,
      )..where((tbl) => tbl.mealId.equals(id))).go();
      await (update(db.meal)..where((tbl) => tbl.basedOnMealId.equals(id)))
          .write(const MealCompanion(basedOnMealId: Value(null)));
      await (delete(db.meal)..where((tbl) => tbl.id.equals(id))).go();
    });
  }

  Future<List<MealData>> getMealsBetween(
    DateTime start,
    DateTime end, {
    int? excludeMealId,
  }) {
    final query = select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([(tbl) => OrderingTerm.asc(tbl.plannedAt)]);
    if (excludeMealId != null) {
      query.where((tbl) => tbl.id.equals(excludeMealId).not());
    }
    return query.get();
  }

  Future<MealData?> getLatestMealBefore(
    DateTime before, {
    required Duration maxAge,
  }) {
    return _latestMealBeforeQuery(before, maxAge: maxAge).getSingleOrNull();
  }

  Stream<MealData?> watchLatestMealBefore(
    DateTime before, {
    required Duration maxAge,
  }) {
    return _latestMealBeforeQuery(before, maxAge: maxAge).watchSingleOrNull();
  }

  Future<List<MealData>> getMealsForIngredient(int ingredientId) {
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(meal.id),
            ),
          ])
          ..where(db.mealIngredients.ingredientId.equals(ingredientId))
          ..limit(10);

    return query.map((row) => row.readTable(db.meal)).get();
  }

  Future<MealData?> getNearestMeal() =>
      (_futurePlannedMealsQuery()..limit(1)).getSingleOrNull();

  /// The collector evaluates this committed snapshot as wall-clock time moves.
  Stream<List<MealData>> watchFuturePlannedMeals() =>
      _futurePlannedMealsQuery().watch();

  SimpleSelectStatement<Meal, MealData> _futurePlannedMealsQuery() {
    return select(db.meal)
      ..where(
        (row) => row.plannedAt.isBiggerThanValue(
          clock.now().toUtc().millisecondsSinceEpoch,
        ),
      )
      ..where((row) => row.purpose.equals('meal'))
      ..where((row) => row.status.equals('planned'))
      ..orderBy([(row) => OrderingTerm.asc(row.plannedAt)]);
  }

  SimpleSelectStatement<Meal, MealData> _latestMealBeforeQuery(
    DateTime before, {
    required Duration maxAge,
  }) {
    final start = before.subtract(maxAge);
    return select(db.meal)
      ..where(
        (tbl) => tbl.plannedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          before.millisecondsSinceEpoch,
        ),
      )
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where(
        (tbl) => tbl.status.isIn([
          'eaten',
          'eaten-extra',
          'eaten-bolused',
          'summarized',
        ]),
      )
      ..orderBy([
        (tbl) =>
            OrderingTerm(expression: tbl.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
  }

  Stream<MealData?> getNearestMealStream() async* {
    Stream<void> mealChangeTrigger() {
      return (select(db.meal)..limit(1)).watch().map((_) {});
    }

    while (true) {
      final current = await getNearestMeal();
      yield current;

      if (current == null) {
        await mealChangeTrigger().first;
        continue;
      }

      final waitDuration = DateTime.fromMillisecondsSinceEpoch(
        current.plannedAt,
      ).difference(clock.now().toUtc());

      if (waitDuration <= Duration.zero) {
        continue;
      }

      try {
        await mealChangeTrigger().timeout(waitDuration).first;
      } on TimeoutException {
        continue;
      }
    }
  }

  Stream<List<MealData>> getAllPlannedMealForToday({DateTime? asOf}) {
    final now = (asOf ?? clock.now()).toLocal();
    final todayMillisecondsSinceEpoch = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;
    // Dashboard must keep unfinished active meals visible even when they were
    // planned before today, otherwise they could block new meals with no way
    // to finish or cancel them from the main screen.
    final query = select(db.meal)
      ..where(
        (tbl) =>
            tbl.plannedAt.isBiggerOrEqualValue(todayMillisecondsSinceEpoch) |
            tbl.status.isIn(
              mealStatusesBlockingAnotherMealActivation.toList(growable: false),
            ) |
            tbl.status.isIn(['eaten', 'eaten-extra', 'eaten-bolused']),
      )
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.status.equals('skipped').not())
      ..where((tbl) => tbl.status.equals('summarized').not())
      ..where((tbl) => tbl.status.equals('interrupted').not())
      ..orderBy([(m) => OrderingTerm(expression: m.plannedAt)]);
    return query.watch();
  }

  Stream<List<MealData>> getAllMeals({int page = 0}) {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(10, offset: page * 10);
    return query.watch();
  }

  Stream<List<MealData>> watchRecentMeals({
    required int limit,
    String? category,
  }) {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (category != null) query.where((row) => row.category.equals(category));
    return query.watch();
  }

  Stream<List<MealData>> watchMealsByName({
    required String queryString,
    required int limit,
    String? category,
  }) {
    final normalizedQuery = queryString.trim().toLowerCase();
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.name.like('%$normalizedQuery%'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    if (category != null) query.where((row) => row.category.equals(category));
    return query.watch();
  }

  Stream<List<MealData>> watchMealsByIngredientIds({
    required List<int> ingredientIds,
    required int limit,
    String? category,
  }) {
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealIngredients.ingredientId.count(
      distinct: true,
    );
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(db.meal.id),
            ),
          ])
          ..where(db.meal.purpose.equals('meal'))
          ..where(db.mealIngredients.ingredientId.isIn(distinctIngredientIds))
          ..groupBy([db.meal.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.meal.plannedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit);

    if (category != null) query.where(db.meal.category.equals(category));
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.meal)).toList(),
    );
  }

  Stream<List<MealData>> watchMealsByNameAndIngredientIds({
    required String queryString,
    required List<int> ingredientIds,
    required int limit,
    String? category,
  }) {
    final normalizedQuery = queryString.trim();
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealIngredients.ingredientId.count(
      distinct: true,
    );
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(db.meal.id),
            ),
          ])
          ..where(db.meal.purpose.equals('meal'))
          ..where(db.meal.name.like('%$normalizedQuery%'))
          ..where(db.mealIngredients.ingredientId.isIn(distinctIngredientIds))
          ..groupBy([db.meal.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.meal.plannedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(limit);

    if (category != null) query.where(db.meal.category.equals(category));
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.meal)).toList(),
    );
  }

  Future<List<MealData>> getMealsBasedOnMeal(int mealId) {
    final query = select(db.meal)
      ..where((tbl) => tbl.basedOnMealId.equals(mealId))
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ]);
    return query.get();
  }

  Future<MealData?> getLatestMealForCopySource({
    int? baseMealId,
    int? mealTemplateId,
  }) async {
    if (baseMealId == null && mealTemplateId == null) {
      return null;
    }

    final query = select(db.meal)
      ..where((tbl) {
        Expression<bool>? condition;
        if (baseMealId != null) {
          condition =
              tbl.id.equals(baseMealId) | tbl.basedOnMealId.equals(baseMealId);
        }
        if (mealTemplateId != null) {
          final templateCondition = tbl.mealTemplateId.equals(mealTemplateId);
          condition = condition == null
              ? templateCondition
              : condition | templateCondition;
        }
        return condition ?? const Constant(false);
      })
      ..orderBy([
        (m) => OrderingTerm(expression: m.plannedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<List<MealData>> searchRecentMeals() {
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(10);

    return query.get();
  }

  Future<List<MealData>> searchMealsByName(String queryString) {
    final normalizedQuery = queryString.trim();
    final query = select(db.meal)
      ..where((tbl) => tbl.purpose.equals('meal'))
      ..where((tbl) => tbl.name.like('%$normalizedQuery%'))
      ..orderBy([
        (m) => OrderingTerm(expression: m.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(10);

    return query.get();
  }

  Future<List<MealData>> searchMealsByIngredientIds({
    required List<int> ingredientIds,
  }) {
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealIngredients.ingredientId.count(
      distinct: true,
    );
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(db.meal.id),
            ),
          ])
          ..where(db.meal.purpose.equals('meal'))
          ..where(db.mealIngredients.ingredientId.isIn(distinctIngredientIds))
          ..groupBy([db.meal.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.meal.updatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(10);

    return query.map((row) => row.readTable(db.meal)).get();
  }

  Future<List<MealData>> searchMealsByNameAndIngredientIds({
    required String queryString,
    required List<int> ingredientIds,
  }) {
    final normalizedQuery = queryString.trim();
    final distinctIngredientIds = ingredientIds.toSet().toList(growable: false);
    final distinctIngredientCount = db.mealIngredients.ingredientId.count(
      distinct: true,
    );
    final query =
        select(db.meal).join([
            innerJoin(
              db.mealIngredients,
              db.mealIngredients.mealId.equalsExp(db.meal.id),
            ),
          ])
          ..where(db.meal.purpose.equals('meal'))
          ..where(db.meal.name.like('%$normalizedQuery%'))
          ..where(db.mealIngredients.ingredientId.isIn(distinctIngredientIds))
          ..groupBy([db.meal.id])
          ..orderBy([
            OrderingTerm(
              expression: distinctIngredientCount,
              mode: OrderingMode.desc,
            ),
            OrderingTerm(
              expression: db.meal.updatedAt,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(10);

    return query.map((row) => row.readTable(db.meal)).get();
  }
}
